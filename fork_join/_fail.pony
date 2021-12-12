use @exit[None](status: U8)
use @fprintf[I32](stream: Pointer[U8] tag, fmt: Pointer[U8] tag, ...)
use @pony_os_stderr[Pointer[U8]]()

// TODO: add issue URL
primitive _Fail
  """
  We hit a place in code that we expected that we should be able to reach.
  """
  fun apply(loc: SourceLoc = __loc) =>
    @fprintf(
      @pony_os_stderr(),
      ("This should never happen: failure in %s at line %s\n" +
       "Please open an issue at XYZ")
       .cstring(),
      loc.file().cstring(),
      loc.line().string().cstring())
    @exit(1)
