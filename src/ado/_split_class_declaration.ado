// Splits a class source file into two files, one that contains the class
// declaration and one that contains the definition of its methods.
pr _split_class_declaration
	vers 11.2

	syntax name(name=source), declaration(str) definition(str)

	_find_mata_source `source'
	mata: split_class_declaration(st_global("r(fn)"), ///
		st_local("declaration"), st_local("definition"))
end

vers 11.2

matamac

mata:

class ClassSplitter {
	public:
		void init(), split(), destroy()

	private:
		`FileHandleS' source, declaration, definition
		void prepend_declaration(), split_declaration(), append_declaration()
}

void ClassSplitter::init(`SS' source, `SS' declaration, `SS' definition)
{
	this.source = fopen(source, "r")
	this.declaration = fopen(declaration, "w")
	this.definition = fopen(definition, "w")
}

void ClassSplitter::destroy()
{
	fclose(source)
	fclose(declaration)
	fclose(definition)
}

void ClassSplitter::prepend_declaration()
{
	fput(declaration, "matamac")
	fput(declaration, "")
	fput(declaration, "mata:")
	fput(declaration, "")
}

void ClassSplitter::append_declaration()
{
	fput(declaration, "")
	fput(declaration, "end")
}

void ClassSplitter::split_declaration()
{
	`RS' class_line, brace_line, i
	`SM' line

	i = 0
	while ((line = fget(source)) != J(0, 0, "")) {
		++i
		pragma unset class_line
		pragma unset brace_line
		if (class_line == .) {
			if (regexm(line, "^class "))
				class_line = i
		}
		else if (brace_line == .) {
			if (line == "}")
				brace_line = i
		}

		fput(class_line == . || i > brace_line ? definition : declaration, line)
	}

	if (brace_line == .)
		_error("invalid declaration")
}

void ClassSplitter::split()
{
	prepend_declaration()
	split_declaration()
	append_declaration()
}

void split_class_declaration(`SS' source, `SS' declaration, `SS' definition)
{
	class ClassSplitter scalar splitter
	splitter.init(source, declaration, definition)
	splitter.split()
}

end
