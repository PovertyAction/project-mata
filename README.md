Project Mata
============

Project Mata is an approach to managing Mata projects. It handles dependencies and macro definitions, and automates the assembly of ado-files.

You have a complex Mata project, perhaps a lengthy ado-file, that you have broken into a series of separate files. Great! By using multiple files, you facilitate code readability and version control.

However, Mata now provides you no means by which to compile a file that depends on other files or to assemble the files into an ado-file. Project Mata offers a set of ado-files to fill this gap.

Table of Contents
-----------------

- Dependency management
  - Declaration dependencies
- Macro definitions
  - Type macros
  - Constants
  - Enumerations
- File structure
- Assembling an ado-file
- Installation

Dependency management
---------------------

Your project has many Mata source files, and you're updating one: `algorithm.mata`. You try compiling it, but you've already run into a challenge: `algorithm.mata` uses the functions defined in two other files, `set.mata` and `graph.mata`. This means you need to run those files anytime you compile `algorithm.mata`:

```
clear mata
do set.mata
do graph.mata
do algorithm.mata
```

Project Mata allows you to automate this step by defining these dependencies at the start of `algorithm.mata`:

```
* Top of file

matainclude set graph

mata:

// Mata code

end
```

Here `matainclude` finds `set.mata` and runs it, then does the same for `graph.mata`. If those files include dependencies, `matainclude` runs those without ever compiling the same file twice. Compiling `algorithm.mata` becomes that much easier:

```
clear mata
do algorithm.mata
```

You can combine these two lines by running `matainclude` from the Command Window:

```
matainclude algorithm
```

### Declaration dependencies

In rare cases, two classes' methods reference each other. In this case, you need to compile the classes' declarations before their method definitions. Do so using `declareclass`. This parses a Mata source file that contains a single class, extracting and compiling only its class declaration.

Here's an example. A container stores a set of member objects. Both the container and its members have names.

```
// Container class declaration

class Container {
	public:
		string scalar name()
		string rowvector member_names()

	private:
		string scalar name
		pointer(class Member scalar) rowvector members
}

// Container method definitions

string rowvector Container::member_names()
{
	real scalar i
	string rowvector names

	names = J(1, length(members), "")
	for (i = 1; i <= length(members); i++)
		names[i] = members[i]->name()
	return(names)
}

...

// Member class declaration

class Member {
	public:
		string scalar name()
		string scalar container_name()

	private:
		string scalar name
		pointer(class Container scalar) scalar container
}

// Member method definitions

string scalar Member::container_name()
	return(container->name())

...
```

`Container::member_names()` calls `Member::name()`, which means that `Member` must be declared before `Container::member_names()` is defined. Likewise, `Container` must be declared before `Member::container_name()` is defined. Mata needs us to declare both classes before defining either.

Say `Container.mata` defines class `Container`, and `Member.mata` defines `Member`. Then you would add `declareclass` to the top of both files:

`Container.mata`

```
declareclass Member

mata:

class Container {
	...
}

...

end
```

`Member.mata`

```
declareclass Container

mata:

class Member {
	...
}

...

end
```

Macro definitions
-----------------

As Bill Gould has [outlined](http://www.stata-journal.com/sjpdf.html?articlenum=pr0040), macros serve a useful purpose in Mata as well as Stata. We wholeheartedly agree.

### Type macros

By storing a long type in a macro of shorter length, we reduce the verbosity of type declarations:

```
local SR string rowvector

...

`SR' union(`SR' list1, `SR' list2)
```

This is especially true for classes and structs:

```
local ListS class my_list_class scalar

...

`ListS' intersection(`ListS' list1, `ListS' list2)
```

Mata has no namespaces, so programmers use long class names to avoid conflicts. With macros, you can use project-specific short names rather than the full class names.

Mata has few exposed classes &mdash; most classes are wrapped in functions &mdash; which means that almost every value is `real`, `string`, or `transmorphic`. Macros allow us to add semantic aliases of these types:

```
// Rowvector of Stata names
local NameR string rowvector
// File handle scalar
local FileHandleS real scalar

...

// We immediately understand the format of these arguments.
void save_dta_subset(`NameR' variables, `FileHandleS' out)
```

Many StataCorp ado-files use macros in Mata: `rename.ado` is an excellent example. These ado-files define their macros immediately above their Mata code.

However, this pattern fails for projects with multiple Mata source files, as each file needs to be able to use project macros. Enter `matamac`.

When you run `matamac` at the top of a Mata source file, it adds the predefined macros of your Project Mata project:

```
* Top of file

matamac

mata:

// Immediately start using type macros.
`SR' union(`SR' list1, `SR' list2) ...

`ListS' intersection(`ListS' list1, `ListS' list2) ...

void save_dta_subset(`NameR' variables, `FileHandleS' out) ...

end
```

You define your project's macros in a file named `.matamac` at the root of your project directory:

```
[type]
	S = string
	List = class my_list_class
	Name = string
	FileHandle = real
```

The line `S = string` defines a series of macros:

```
local SS string scalar
local SV string vector
local SR string rowvector
local SC string colvector
local SM string matrix
```

In keeping with StataCorp convention, all Project Mata type macros end in a capital letter that designates the orgtype.

The line `List = class my_list_class`, defining a class type, results in a similar set of macros:

```
local List my_list_class
local ListS class my_list_class scalar
local ListV class my_list_class vector
local ListR class my_list_class rowvector
local ListC class my_list_class colvector
local ListM class my_list_class matrix
```

Here the class name is stored in a macro that can be used in the class definition:

```
class `List' {
	public void concat()
	...
}

void `List'::concat(`ListS' list)
```

Class macros help overcome the lack of namespaces. With them, no project code need refer to actual class names, which can be long without degrading readability.

### Constants

A `.matamac` file may include simple constants in addition to types:

```
[type]
	S = string
	List = class my_list_class
[cons]
	ImportantProjectValue = something
	EssentialProjectSetting = something else
```

The `cons` section of this `.matamac` file defines these macros:

```
local ImportantProjectValue something
local EssentialProjectSetting something else
```

### Enumerations

Enumerations allow you to define a Mata type that equals one of a fixed set of values. (Bill Gould discusses these in his Stata Journal article.)

For example, say a function yields a return code that indicates the result of a file write. The operation could be successful or it could fail because the file already exists or because its parent directory does not exist. `matamac` will define macros like these:

```
local WriteResultS real scalar
...
local WriteResultM real matrix
local ResultSuccess    0
local ResultFileExists 1
local ResultNoParent   2
```

Leading to client code like this:

```
`WriteResultS' result
result = write_file(some_file)
if (result == `ResultSuccess')
	display("We did it!")
else if (result == `ResultFileExists')
	...
else if (result == `ResultNoParent')
	...
```

This enumeration's definition in `.matamac` appears as follows:

```
[type]
	S = string
	List = class my_list_class
[enum]
	WriteResult = (Result) Success FileExists NoParent
```

`WriteResult` designates a name for the enumeration's type macros, while `(Result)` prefixes the names of the enumeration's value macros.

File structure
--------------

Project Mata requires your project to follow a defined structure.

You must store your files in a Git repository. Project Mata uses the user-written program `stgit` to identify the root of the repository.

At the repository root, define `.matamac` for project macros. Every Mata source file must run `matamac`.

Store your source files, both Stata and Mata, in directory `src`. Project Mata ado-files do not use other directories, but we recommend that you create a directory named `doc` for project documentation. For example, `doc/help` could contain Stata help files while `doc/develop` stores documentation for project developers.

`src` can use whatever directory structure you prefer. We recommend a directory named `main` for primary files and one named `cscript` for the certification script.

Every source file must be uniquely identified by its base name. For example, a file named `something.mata` cannot exist in two directories. Base names must be valid Stata names.

Classes follow their own structure. Each class should have its own type macro. Every class must be defined in its own file whose name is the same as the class type macro. For example, we may use the macro `List` for class `my_list_class`:

`.matamac`

```
[type]
	List = class my_list_class
```

Then the source file that contains the definition of `my_list_class` must be named `List.mata`.

Assembling an ado-file
----------------------

Use `write_ado` to assemble the source files of a Project Mata project into an ado-file. Specify three sets of source files:

1. A Stata file that defines the program and calls Mata. Specify the file's relative path from the `src` directory.
2. Mata files. Just specify the sources' names.
3. (Optional) Mata files whose class declarations must be compiled before other classes' definitions. Specify source names.

For example:

```
#delimit ;
write_ado using my_ado.ado,
	stata(main/stata.do)
	mata(
		Container
		Member
		set
		graph
		algorithm
	)
	class_declarations(
		Container
		Member
	)
;
#delimit cr
```

Installation
------------

To use Project Mata, clone this repository and add `src/ado` to your ado-path.

Project Mata requires the user-written program `stgit` to manage Git repositories.
