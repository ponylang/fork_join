use "ponytest"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestEvenlySplitDataElementsWithMoreDataElements)
    test(_TestEvenlySplitDataElementsWithLessDataElements)
    test(_TestEvenlySplitDataElementsWithEvenDataElements)

class iso _TestEvenlySplitDataElementsWithMoreDataElements is UnitTest
  """
  Test splitting data elements across x workers where there's more data elements
  than workers and the work isn't evenly splittable.
  """
  fun name(): String =>
    "fork_join/EvenlySplitDataElements/more"

  fun apply(h: TestHelper) =>
    var expected: Array[USize] = [2;1]
    var actual: Array[USize] val = EvenlySplitDataElements(3, 2)
    h.assert_array_eq[USize](expected, actual)

    expected = [3;2]
    actual = EvenlySplitDataElements(5, 2)
    h.assert_array_eq[USize](expected, actual)

    expected = [6;6;5]
    actual = EvenlySplitDataElements(17, 3)
    h.assert_array_eq[USize](expected, actual)

    expected = [5;4;4;4;4]
    actual = EvenlySplitDataElements(21, 5)
    h.assert_array_eq[USize](expected, actual)

class iso _TestEvenlySplitDataElementsWithLessDataElements is UnitTest
  """
  Test splitting elements across x workers where there are fewer data elements
  than workers and the work isn't evenly splittable.
  """

  fun name(): String =>
    "fork_join/EvenlySplitDataElements/less"

  fun apply(h: TestHelper) =>
    var expected: Array[USize] = [1;0]
    var actual: Array[USize] val = EvenlySplitDataElements(1, 2)
    h.assert_array_eq[USize](expected, actual)

    expected = [1;0; 0]
    actual = EvenlySplitDataElements(1, 3)
    h.assert_array_eq[USize](expected, actual)

    expected = [1;1;0]
    actual = EvenlySplitDataElements(2, 3)
    h.assert_array_eq[USize](expected, actual)

    expected = [1;1;1;0;0]
    actual = EvenlySplitDataElements(3, 5)
    h.assert_array_eq[USize](expected, actual)

class iso _TestEvenlySplitDataElementsWithEvenDataElements is UnitTest
  """
  Test splitting elements across x workers where the work can be evenly
  distributed.
  """
  fun name(): String =>
    "fork_join/EvenlySplitDataElements/even"

  fun apply(h: TestHelper) =>
    var expected: Array[USize] = [1;1]
    var actual: Array[USize] val = EvenlySplitDataElements(2, 2)
    h.assert_array_eq[USize](expected, actual)

    expected = [5;5]
    actual = EvenlySplitDataElements(10, 2)
    h.assert_array_eq[USize](expected, actual)

    expected = [3;3;3]
    actual = EvenlySplitDataElements(9, 3)
    h.assert_array_eq[USize](expected, actual)

    expected = [5;5;5;5;5]
    actual = EvenlySplitDataElements(25, 5)
    h.assert_array_eq[USize](expected, actual)
