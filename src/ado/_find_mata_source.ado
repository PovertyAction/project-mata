pr _find_mata_source
	vers 11.2

	syntax name(name=source)

	mata: find_source("source")
end

vers 11.2

matamac

mata:

`SS' project_root()
{
	stata("_find_project_root")
	return(st_global("r(path)"))
}

`SR' external_projects()
{
	stata("_external_projects")
	return(tokens(st_global("r(roots)")))
}

// Searches a directory and its subdirectories for a file, returning the file's
// parent directory. The filename must be lowercase.
`SS' find_parent_dir(`SS' basename, `SS' dir)
{
	`RS' i
	`SS' parent
	`SR' subdirs

	if (anyof(strlower(dir(dir, "files", "*")), basename))
		return(dir)

	subdirs = dir(dir, "dirs", "*")
	for (i = 1; i <= length(subdirs); i++) {
		parent = find_parent_dir(basename, pathjoin(dir, subdirs[i]))
		if (parent != "")
			return(parent)
	}

	return("")
}

void find_source(`LclNameS' _source)
{
	`RS' i
	`SS' dir, basename, lower
	`SR' roots

	basename = st_local(_source) + ".mata"
	lower = strlower(basename)
	roots = project_root(), external_projects()
	pragma unset dir
	for (i = 1; dir == "" && i <= length(roots); i++)
		dir = find_parent_dir(lower, pathjoin(roots[i], "src"))
	if (dir == "") {
		errprintf("file %s not found\n", basename)
		exit(601)
	}

	st_global("r(fn)", pathjoin(dir, basename))
}

end
