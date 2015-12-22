pr matamac
	vers 11.2

	syntax

	mata: matamac()
end

vers 11.2

loc RS real scalar
loc SS string scalar
loc SR string rowvector
loc SC string colvector
loc SM string matrix
loc TM transmorphic matrix

mata:

/* -------------------------------------------------------------------------- */
					/* MataTypes */

class MataTypes {
	public:
		`SR' eltypes(), orgtypes()
		void new()

	private:
		static `SR' eltypes, orgtypes
}

void MataTypes::new()
{
	if (length(eltypes) == 0) {
		eltypes = "complex", "numeric", "pointer", "real", "string",
			"transmorphic"
		orgtypes = "scalar", "vector", "rowvector", "colvector", "matrix"
	}
}

`SR' MataTypes::eltypes()
	return(eltypes)

`SR' MataTypes::orgtypes()
	return(orgtypes)

					/* MataTypes */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* Setting */

class Setting {
	public:
		`SS' key(), value()
		`SM' locals()
		void init()

	protected:
		`RS' is_name()
		virtual void validate(), add_all()
		void add_local(), add_locals()

	private:
		`SS' key, value
		`SM' locals
}

void Setting::validate()
	_error("method not implemented")

void Setting::add_all()
	_error("method not implemented")

void Setting::init(`SS' key, `SS' value)
{
	this.key = key
	this.value = value
	locals = J(0, 2, "")

	validate()
	add_all()
}

`SS' Setting::key()
	return(key)

`SS' Setting::value()
	return(value)

`SM' Setting::locals()
	return(locals)

`RS' Setting::is_name(`SS' name)
	return(name == strtoname(name) && name != "" && !strpos(name, "`")) //"

void Setting::add_local(`SS' name, `SS' contents)
{
	if (name == "")
		_error("blank name")
	if (!is_name("_" + name))
		_error("invalid name")

	// These characters don't play well with -c_local-.
	if (strpos(contents, "`") || strpos(contents, "$")) //"
		_error("invalid contents")

	locals = locals \ name, contents
}

void Setting::add_locals(`SM' locals)
{
	`RS' i
	if (cols(locals) != 2)
		_error("invalid matrix")
	for (i = 1; i <= rows(locals); i++)
		add_local(locals[i, 1], locals[i, 2])
}

					/* Setting */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* ConsSetting */

class ConsSetting extends Setting {
	protected virtual void validate(), add_all()
}

void ConsSetting::validate()
	return

void ConsSetting::add_all()
	add_local(key(), value())

					/* ConsSetting */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* PrimitiveTypeSetting */

class PrimitiveTypeSetting extends ConsSetting {
	protected:
		virtual void validate()

	private:
		static class MataTypes scalar types
}

void PrimitiveTypeSetting::validate()
{
	`SR' tokens
	`TM' tokenizer

	super.validate()

	tokenizer = tokeninit(" " + char(9), "", "", 0, 0)
	tokenset(tokenizer, value())
	tokens = tokengetall(tokenizer)
	if (length(tokens) < 2)
		_error("invalid type")
	if (!anyof(types.eltypes(), tokens[1]))
		_error("invalid eltype")
	if (!anyof(types.orgtypes(), tokens[2]))
		_error("invalid orgtype")
}

					/* PrimitiveTypeSetting */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* EltypeSetting */

class EltypeSetting extends Setting {
	protected:
		virtual void add_all()

	private:
		static class MataTypes scalar types
}

void EltypeSetting::add_all()
{
	`RS' i
	`SS' org_type, name, value

	for (i = 1; i <= length(types.orgtypes()); i++) {
		org_type = types.orgtypes()[i]
		name = sprintf("%s%s", key(), strupper(substr(org_type, 1, 1)))
		value = sprintf("%s %s", value(), org_type)
		add_local(name, value)
	}
}

					/* EltypeSetting */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* PrimitiveEltypeSetting */

class PrimitiveEltypeSetting extends EltypeSetting {
	protected:
		virtual void validate()

	private:
		static class MataTypes scalar types
}

void PrimitiveEltypeSetting::validate()
{
	if (!anyof(types.eltypes(), value()))
		_error("invalid eltype")
}

					/* PrimitiveEltypeSetting */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* ClassEltypeSetting */

class ClassEltypeSetting extends EltypeSetting {
	protected:
		virtual void validate(), add_all()

	private:
		`SS' klass
}

void ClassEltypeSetting::validate()
{
	`SR' tokens
	`TM' tokenizer

	tokenizer = tokeninit(" " + char(9), "", "", 0, 0)
	tokenset(tokenizer, value())
	tokens = tokengetall(tokenizer)

	if (length(tokens) != 2)
		_error("invalid type")
	if (!anyof(("struct", "class"), tokens[1]))
		_error("struct or class expected")

	klass = tokens[2]
	if (!is_name(klass))
		_error("invalid class name")
}

void ClassEltypeSetting::add_all()
{
	super.add_all()
	add_local(key(), klass)
}

					/* ClassEltypeSetting */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* TypeSetting */

class TypeSetting extends Setting {
	protected:
		virtual void validate(), add_all()

	private:
		class Setting scalar setting
}

void TypeSetting::validate()
{
	`SR' tokens
	`TM' tokenizer

	tokenizer = tokeninit(" " + char(9), "", "", 0, 0)
	tokenset(tokenizer, value())
	tokens = tokengetall(tokenizer)

	if (length(tokens) == 0)
		_error("no tokens")

	if (anyof(("struct", "class"), tokens[1]))
		setting = ClassEltypeSetting()
	else {
		if (length(tokens) == 1)
			setting = PrimitiveEltypeSetting()
		else if (length(tokens) == 2)
			setting = PrimitiveTypeSetting()
		else
			_error("too many tokens")
	}

	setting.init(key(), value())
}

void TypeSetting::add_all()
	add_locals(setting.locals())

					/* TypeSetting */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* EnumSetting */

class EnumSetting extends Setting {
	protected:
		virtual void validate(), add_all()

	private:
		`SS' prefix
		`SR' values
}

void EnumSetting::validate()
{
	`SR' tokens
	`TM' tokenizer

	tokenizer = tokeninit(" " + char(9), ("(", ")"), "", 0, 0)
	tokenset(tokenizer, value())
	tokens = tokengetall(tokenizer)

	if (length(tokens) < 4)
		_error("invalid type")
	if (tokens[1] != "(" || tokens[3] != ")")
		_error("parentheses not found")

	prefix = tokens[2]
	values = tokens[|4 \ length(tokens)|]
}

void EnumSetting::add_all()
{
	`RS' i
	class PrimitiveEltypeSetting scalar type

	type.init(key(), "real")
	add_locals(type.locals())

	for (i = 1; i <= length(values); i++)
		add_local(prefix + values[i], strofreal(i))
}

					/* EnumSetting */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* MataMacFile */

class MataMacFile {
	public:
		`SM' parse()
		void new()

	private:
		`SS' section
		`SM' locals
		class Setting scalar setting()
		void parse_line(), _trim(), split_line()
}

void MataMacFile::new()
	locals = J(0, 2, "")

void MataMacFile::_trim(`SS' s)
{
	`RS' first, last
	`SR' ws

	ws = " ", char(9)
	for (first = 1; first <= strlen(s) && anyof(ws, substr(s, first, 1)); first++)
		;
	if (first > strlen(s)) {
		s = ""
		return
	}
	for (last = strlen(s); last >= 1 && anyof(ws, substr(s, last, 1)); last--)
		;
	s = substr(s, first, last - first + 1)
}

void MataMacFile::split_line(`SS' line, `SS' key, `SS' value)
{
	`RS' pos
	`SR' tokens

	pos = strpos(line, "=")
	if (pos == 0)
		_error("= not found")

	_trim(key = substr(line, 1, pos - 1))
	_trim(value = substr(line, pos + 1, .))

	tokens = tokens(value)
	if (length(tokens) == 1)
		value = tokens[1]
}

class Setting scalar MataMacFile::setting(`SS' key, `SS' value)
{
	class Setting scalar setting

	if (section == "cons")
		setting = ConsSetting()
	else if (section == "type")
		setting = TypeSetting()
	else if (section == "enum")
		setting = EnumSetting()
	else
		_error(sprintf("invalid section '%s'", section))

	setting.init(key, value)

	return(setting)
}

void MataMacFile::parse_line(`SS' line)
{
	`SS' key, value

	_trim(line)

	if (line == "" || regexm(line, "^(\*|//)"))
		return

	if (regexm(line, "^\[(.+)\]$"))
		section = regexs(1)
	else {
		pragma unset key
		pragma unset value
		split_line(line, key, value)
		locals = locals \ this.setting(key, value).locals()
	}
}

`SM' MataMacFile::parse()
{
	`RS' fh
	`SM' line

	fh = fopen(pathjoin(st_global("MATAMAC_ROOT_PATH"), ".matamac"), "r")
	while ((line = fget(fh)) != J(0, 0, ""))
		parse_line(line)
	fclose(fh)

	return(locals)
}

					/* MataMacFile */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* main */

void set_root_path()
{
	`SS' name, dir, curdir

	name = "MATAMAC_ROOT_PATH"
	dir = st_global(name)
	// Run -stgit- only if necessary.
	if (dir == "" || substr(pwd(), 1, strlen(dir)) != dir) {
		stata("qui stgit")
		curdir = pwd()
		chdir(st_global("r(git_dir)"))
		chdir("..")
		st_global(name, pwd())
		chdir(curdir)
	}
}

void define_locals(`SM' locals)
{
	`RS' i
	for (i = 1; i <= rows(locals); i++)
		stata(sprintf(`"c_local %s `"%s"'"', locals[i, 1], locals[i, 2]))
}

void define_global(`SM' locals)
{
	`SS' name
	name = "_matamac_locals"
	rmexternal(name)
	*crexternal(name) = locals
	st_global("r(mata)", name)
}

void parse_config()
{
	`SM' locals
	class MataMacFile scalar config

	locals = config.parse()
	define_locals(locals)
	define_global(locals)
}

void matamac()
{
	set_root_path()
	parse_config()
}

					/* main */
/* -------------------------------------------------------------------------- */

end
