pr writeado
	vers 11.2

	syntax using/, stata(str) mata(namelist) [class_declarations(namelist)]

	vers `=_caller()': ///
		mata: write_ado("using", "stata", "class_declarations", "mata")
end

vers 11.2

matamac

mata:

/* -------------------------------------------------------------------------- */
					/* AdoComponents */

class AdoComponents {
	public:
		`SS' stata()
		`NameR' class_declarations(), mata()
		void init()

	private:
		`SS' stata
		`NameR' class_declarations, mata
}

void AdoComponents::init(`SS' stata, `NameR' class_declarations, `NameR' mata)
{
	this.stata = stata
	this.class_declarations = class_declarations
	this.mata = mata
}

`SS' AdoComponents::stata()
	return(stata)

`NameR' AdoComponents::class_declarations()
	return(class_declarations)

`NameR' AdoComponents::mata()
	return(mata)

					/* AdoComponents */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* SplitClass */

class SplitClass {
	public:
		`SS' declaration(), definition()
		void init()

	private:
		`SS' declaration, definition
}

void SplitClass::init(`NameS' source)
{
	declaration = st_tempfilename()
	definition  = st_tempfilename()
	stata(sprintf("_split_class_declaration %s, declaration(%s) definition(%s)",
		source, declaration, definition))
}

`SS' SplitClass::declaration()
	return(declaration)

`SS' SplitClass::definition()
	return(definition)

					/* SplitClass */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* AdoWriter */

class AdoWriter {
	public:
		void new(), init(), write()

	private:
		static `SR' COMMANDS_TO_SKIP
		static `TM' WHITE_SPACE_TOKENIZER

		`SS' ado_file
		`TM' split_classes
		`FileHandleS' out
		pointer(class AdoComponents scalar) scalar components

		// Project Mata helpers
		`SS' find_source()
		pointer(class SplitClass scalar) scalar split_class()
		void split_class_declarations()

		// Write methods
		void write_stata(), append(), write_version(), write_macros(),
			write_class_declarations(), write_mata_file(), write_mata()
}

void AdoWriter::new()
{
	if (length(COMMANDS_TO_SKIP) == 0) {
		COMMANDS_TO_SKIP = "vers", "versi", "versio", "version", "matamac",
			"matainclude", "declareclass"
		WHITE_SPACE_TOKENIZER = tokeninit(" " + char(9), "", "", 0, 0)
	}
}

void AdoWriter::init(class AdoComponents scalar components, `SS' ado_file)
{
	this.components = &components
	this.ado_file = ado_file
}

`SS' AdoWriter::find_source(`NameS' source)
{
	stata("_find_mata_source " + source)
	return(st_global("r(fn)"))
}

void AdoWriter::split_class_declarations()
{
	`RS' i
	`NameS' source
	pointer (class SplitClass scalar) scalar klass

	split_classes = asarray_create()
	for (i = 1; i <= length(components->class_declarations()); i++) {
		source = components->class_declarations()[i]
		klass = &(SplitClass())
		klass->init(source)
		asarray(split_classes, source, klass)
	}
}

pointer(class SplitClass scalar) scalar AdoWriter::split_class(`NameS' source)
	return(asarray(split_classes, source))

void AdoWriter::append(`SS' filename)
{
	`FileHandleS' in
	`SM' line
	in = fopen(filename, "r")
	while ((line = fget(in)) != J(0, 0, ""))
		fput(out, line)
	fput(out, "")
	fclose(in)
}

void AdoWriter::write_stata()
{
	`SS' filename
	filename = sprintf("%s/src/%s",
		st_global("MATAMAC_ROOT_PATH"), components->stata())
	append(filename)
}

void AdoWriter::write_version()
	fwrite(out, sprintf("version %f\n\n", callersversion()))

void AdoWriter::write_macros()
{
	`RS' i
	`SM' locals

	stata("matamac")
	locals = *findexternal(st_global("r(mata)"))
	for (i = 1; i <= rows(locals); i++)
		fput(out, sprintf(`"local %s `"%s"'"', locals[i, 1], locals[i, 2]))
	fput(out, "")
}

void AdoWriter::write_mata_file(`SS' filename, `SS' header)
{
	`SR' tokens
	`SM' line
	`TM' tokenizer
	`FileHandleS' in

	in = fopen(filename, "r")
	fwrite(out, sprintf("// %s\n\n", header))

	while ((line = fget(in)) != J(0, 0, "")) {
		tokenset(tokenizer = WHITE_SPACE_TOKENIZER, line)
		tokens = tokengetall(tokenizer)
		if (length(tokens) > 0) {
			if (anyof(COMMANDS_TO_SKIP, tokens[1]))
				line = "*" + line
		}
		fput(out, line)
	}

	fclose(in)
}

void AdoWriter::write_class_declarations()
{
	`RS' i
	`SS' filename, header
	`NameS' source

	split_class_declarations()
	for (i = 1; i <= length(components->class_declarations()); i++) {
		source = components->class_declarations()[i]
		filename = this.split_class(source)->declaration()
		header = sprintf("%s class declaration", source)
		write_mata_file(filename, header)
		fput(out, "")
	}
}

void AdoWriter::write_mata()
{
	`RS' i
	`SS' filename
	`NameS' source

	for (i = 1; i <= length(components->mata()); i++) {
		source = components->mata()[i]
		if (anyof(components->class_declarations(), source))
			filename = this.split_class(source)->definition()
		else
			filename = find_source(source)
		write_mata_file(filename, source)
		if (i != length(components->mata()))
			fput(out, "")
	}
}

void AdoWriter::write()
{
	`SS' in_progress

	in_progress = st_tempfilename()
	out = fopen(in_progress, "w")

	write_stata()
	write_version()
	write_macros()
	write_class_declarations()
	write_mata()

	fclose(out)
	stata(sprintf(`"qui copy %s `"%s"', replace"', in_progress, ado_file))
}

					/* AdoWriter */
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* main */

void write_ado(`LclNameS' _ado_file, `LclNameS' _stata,
	`LclNameS' _class_declarations, `LclNameS' _mata)
{
	class AdoComponents scalar components
	class AdoWriter scalar writer
	components.init(
		st_local(_stata),
		tokens(st_local(_class_declarations)),
		tokens(st_local(_mata))
	)
	writer.init(components, st_local(_ado_file))
	writer.write()
}

					/* main */
/* -------------------------------------------------------------------------- */

end
