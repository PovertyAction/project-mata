* Returns the absolute path of the root of the project.
pr _find_project_root
	vers 11.2

	syntax

	mata: find_project_root()
end

vers 11.2

mata:

void find_project_root()
{
	string scalar dir, parent
	dir = pwd()
	while (1) {
		if (length(dir(dir, "files", ".matamac")) > 0) {
			st_global("r(path)", dir)
			return
		}

		pragma unset parent
		pathsplit(dir, parent, "")
		if (parent == "") {
			errprintf(".matamac not found\n")
			exit(601)
		}
		dir = parent
	}
}

end
