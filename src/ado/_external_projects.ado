// Returns a list of the absolute paths of the roots of the project's external
// dependencies.
pr _external_projects
	vers 11.2

	syntax

	mata: external_projects()
end

vers 11.2

loc RS real scalar
loc SS string scalar
loc SR string rowvector
loc SM string matrix

mata:

class ExternalProjects {
	public:
		`SR' list()
		void new()

	private:
		`SS' filename

		`SS' abspath()
		`SR' parse_file()
		void parse_line()
}

void ExternalProjects::new()
{
	stata("_find_project_root")
	filename = pathjoin(st_global("r(path)"), ".external")
}

`SS' ExternalProjects::abspath(`SS' fastcd_code)
{
	`SS' curdir, cmd, path
	curdir = pwd()
	cmd = "c " + fastcd_code
	stata("qui " + cmd)
	if (pwd() == curdir) {
		errprintf("invalid .external project: command\n")
		printf("{cmd}%s\n", cmd)
		errprintf("had no effect\n")
		exit(601)
	}
	path = pwd()
	chdir(curdir)
	// Needed to update the working directory bar: -chdir()- does not change it.
	stata("qui cd .")
	return(path)
}

void ExternalProjects::parse_line(`SS' line, `SR' list)
{
	line = strtrim(line)
	if (line == "" || regexm(line, "^(\*|//)"))
		return
	list = list, abspath(line)
}

`SR' ExternalProjects::parse_file()
{
	`RS' fh
	`SR' list
	`SM' line

	pragma unset list
	fh = fopen(filename, "r")
	while ((line = fget(fh)) != J(0, 0, ""))
		parse_line(line, list)
	fclose(fh)
	return(list)
}

`SR' ExternalProjects::list()
{
	if (!fileexists(filename))
		return(J(1, 0, ""))
	return(parse_file())
}

void external_projects()
{
	`SR' list
	class ExternalProjects scalar ep
	list = ("`" + `"""') :+ ep.list() :+ (`"""' + "'") //"
	st_global("r(roots)", invtokens(list))
}

end
