use "ponytest"

actor \nodoc\ Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestCollectorTerminate)
    test(_TestEndToEnd)
    test(_TestEvenlySplitDataElementsWithMoreDataElements)
    test(_TestEvenlySplitDataElementsWithLessDataElements)
    test(_TestEvenlySplitDataElementsWithEvenDataElements)
    test(_TestJobTerminate)
