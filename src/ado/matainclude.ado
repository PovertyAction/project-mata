pr matainclude
	vers 11.2

	syntax namelist(name=sources)

	mata: mata_include("sources")
end

vers 11.2

matamac

mata:

/* -------------------------------------------------------------------------- */
					/* SourceCompiler */

class SourceCompiler {
	public:
		`RS' run()
		void new()

	private:
		`TM' ran
		`RS' run_source()
		`SS' find_source()
}

void SourceCompiler::new()
	ran = asarray_create()

`SS' SourceCompiler::find_source(`NameS' source)
{
	stata("cap noi _find_mata_source " + source)
	return(c("rc") == 0 ? st_global("r(fn)") : "")
}

`RS' SourceCompiler::run_source(`NameS' source)
{
	`SS' filename

	if (asarray_contains(ran, source))
		return(0)

	filename = find_source(source)
	if (filename == "")
		return(601)

	stata(sprintf(`"cap noi do `"%s"'"', filename))
	asarray(ran, source, `True')
	return(c("rc"))
}

`RS' SourceCompiler::run(`NameR' sources)
{
	`RS' rc, i

	rc = 0
	for (i = 1; i <= length(sources) && rc == 0; i++) {
		printf("{txt}{cmd:matainclude}: running {res:%s}.\n", sources[i])
		rc = run_source(sources[i])
		if (rc == 0)
			display("")
	}

	return(rc)
}

					/* SourceCompiler */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* MataWarnings */

// Summary of previous lines
struct LogLineState {
	`SS' method
	`BooleanS' any_warning, previous_was_warning
}

class MataWarnings {
	public:
		void new(), log(), list(), close()

	private:
		static `SS' METHOD_REGEX
		`SS' filename
		`NameS' name

		`SR' log_names()
		void set_name(), parse_line()
}

void MataWarnings::new()
{
	if (METHOD_REGEX == "") {
		METHOD_REGEX = "^: ([\w()\`' ]+ )?(\`[\w]+' *:: *[\w]+) *\("
		METHOD_REGEX = subinstr(METHOD_REGEX, "\w", "a-zA-z0-9_", .)
	}
}

`SR' MataWarnings::log_names()
{
	`RS' i
	`RM' n
	`SR' names

	stata("qui log query _all")
	n = st_numscalar("r(numlogs)")
	if (n == J(0, 0, .))
		n = 0

	names = J(1, n, "")
	for (i = 1; i <= n; i++)
		names[i] = st_global(sprintf("r(name%f)", i))

	return(names)
}

void MataWarnings::set_name()
{
	`SR' names
	names = log_names()
	do {
		name = st_tempname()
	} while (anyof(names, name))
}

void MataWarnings::log()
{
	filename = st_tempfilename()
	set_name()
	stata(sprintf("qui log using %s, name(%s) t", filename, name))
}

void MataWarnings::parse_line(`SS' line, struct LogLineState scalar state)
{
	if (regexm(line, "^note: (.+)$")) {
		if (!state.any_warning)
			printf("{txt}Mata issued warning(s):\n")
		if (!state.previous_was_warning)
			printf("\n{res}%s\n", state.method)
		printf("{txt}%s\n", regexs(1))
		state.any_warning = state.previous_was_warning = `True'
	}
	else {
		if (regexm(line, METHOD_REGEX))
			state.method = subinstr(regexs(2), " ", "", .) + "()"
		state.previous_was_warning = `False'
	}
}

void MataWarnings::close()
	stata("qui log close " + name)

void MataWarnings::list()
{
	`SM' line
	struct LogLineState scalar state
	`FileHandleS' in

	close()

	state.any_warning = state.previous_was_warning = `False'
	in = fopen(filename, "r")
	while ((line = fget(in)) != J(0, 0, ""))
		parse_line(line, state)
	fclose(in)
	if (!state.any_warning)
		printf("{txt}Mata issued no warnings.\n")
}

					/* MataWarnings */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* MataInclude */

class MataInclude {
	public:
		void new(), run()

	private:
		static `SS' COMPILER_NAME
		`BooleanS' is_parent
		pointer(class MataWarnings scalar) scalar warnings
		pointer(class SourceCompiler scalar) scalar compiler

		void init_parent(), init(), assert_noisily(), set_compiler(),
			exit_parent()
}

void MataInclude::new()
{
	if (COMPILER_NAME == "")
		COMPILER_NAME = "_matainclude_compiler"
}

// A call of -matainclude- is either a parent call or a child call:
// -matainclude- may call itself through a source file.
void MataInclude::init_parent()
{
	is_parent = findexternal(COMPILER_NAME) == NULL
	if (is_parent) {
		stata("clear mata")
		warnings = &(MataWarnings())
		warnings->log()
	}
}

void MataInclude::assert_noisily()
{
	if (!c("noisily"))
		_error("quietly not allowed")
}

void MataInclude::set_compiler()
{
	compiler = findexternal(COMPILER_NAME)
	if (compiler == NULL) {
		compiler = crexternal(COMPILER_NAME)
		*compiler = SourceCompiler()
	}
}

void MataInclude::init()
{
	// -noisily- is needed for the MataWarnings log.
	assert_noisily()
	set_compiler()
	display("")
}

void MataInclude::exit_parent(`RS' rc)
{
	if (is_parent) {
		if (rc == 0)
			warnings->list()
		else
			warnings->close()
		rmexternal(COMPILER_NAME)
	}
}

void MataInclude::run(`NameR' sources)
{
	`RS' rc
	init_parent()
	init()
	rc = compiler->run(sources)
	exit_parent(rc)
	exit(rc)
}

void mata_include(`LclNameS' _sources)
{
	class MataInclude scalar call
	call.run(tokens(st_local(_sources)))
}

					/* MataInclude */
/* -------------------------------------------------------------------------- */

end
