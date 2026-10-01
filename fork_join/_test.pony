use pt = "pony_test"

actor \nodoc\ Main is pt.TestList
  new create(env: Env) => pt.PonyTest(env, this)
  new make() => None

  fun tag tests(test: pt.PonyTest) =>
    test(_TestCollectorTerminate)
    test(_TestEndToEnd)
    test(_TestEvenlySplitDataElementsWithMoreDataElements)
    test(_TestEvenlySplitDataElementsWithLessDataElements)
    test(_TestEvenlySplitDataElementsWithEvenDataElements)
    test(_TestJobTerminate)
