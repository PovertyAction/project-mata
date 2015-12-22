pr _find_mata_source
	vers 11.2

	syntax name(name=source)

	mata: find_source("source")
end

vers 11.2

matamac

mata:

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
	`SS' basename, dir

	basename = st_local(_source) + ".mata"
	dir = find_parent_dir(strlower(basename),
		pathjoin(st_global("MATAMAC_ROOT_PATH"), "src"))
	if (dir == "") {
		errprintf("file %s not found\n", basename)
		exit(601)
	}

	st_global("r(fn)", pathjoin(dir, basename))
}

end
