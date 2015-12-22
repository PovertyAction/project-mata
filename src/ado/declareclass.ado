pr declareclass
	vers 11.2

	syntax namelist(name=sources)

	foreach source of loc sources {
		di _n as txt "{cmd:declareclass}: including {res:`source'}."

		tempfile declaration definition
		_split_class_declaration `source', ///
			declaration(`declaration') definition(`definition')
		do `declaration'
	}
end
