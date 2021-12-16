use "ponytest"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestEndToEnd)
    test(_TestEvenlySplitDataElementsWithMoreDataElements)
    test(_TestEvenlySplitDataElementsWithLessDataElements)
    test(_TestEvenlySplitDataElementsWithEvenDataElements)

class iso _TestEndToEnd is UnitTest
  """
  End-to-end test of simple identity application.

  This gives us a decent amount of coverage for "happy path" wiring of our
  various framework actors.
  """
  fun name(): String =>
    "fork_join/EndToEnd"

  fun apply(h: TestHelper) =>
    h.long_test(1_000_000_000)
    h.expect_action("collector.finish()")

    let expected: Array[U8] val = recover val [1;3;5;7;9;57;4;3;2;1;88;18] end
    let input: Array[U8] iso = recover iso expected.clone() end

    Coordinator[Array[U8] iso, Array[U8] val](
      _EndToEndBuilder,
      _EndToEndGenerator(consume input),
      _EndToEndCollector(h, expected))

class _EndToEndBuilder is WorkerBuilder[Array[U8] iso, Array[U8] val]
  fun ref apply(): Worker[Array[U8] iso, Array[U8] val] iso^ =>
    _EndToEndWorker

class _EndToEndGenerator is Generator[Array[U8] iso]
  var _working_set: Array[U8] iso
  var _distribution_set: Array[USize] = _distribution_set.create()

  new iso create(working_set: Array[U8] iso) =>
    _working_set = consume working_set

  fun ref init(workers: USize) =>
    None

  fun ref apply(): Array[U8] iso^ ? =>
    if _working_set.size() == 0 then
      error
    end

    (let batch, _working_set) = (consume _working_set).chop(1)
    consume batch

class _EndToEndCollector is Collector[Array[U8] iso, Array[U8] val]
  let _collected: Array[U8] = _collected.create()
  let _helper: TestHelper
  let _expected: Array[U8] val

  new iso create(helper: TestHelper, expected: Array[U8] val) =>
    _helper = helper
    _expected = expected

  fun ref collect(runner: CollectorRunner[Array[U8] iso, Array[U8] val] ref,
    result: Array[U8] val)
  =>
    for item in result.values() do
      _collected.push(item)
    end

  fun ref finish() =>
    _helper.assert_array_eq_unordered[U8](_expected, _collected)
    _helper.complete_action("collector.finish()")

class _EndToEndWorker is Worker[Array[U8] iso, Array[U8] val]
  var _working_set: Array[U8] val = recover val _working_set.create() end

  fun ref receive(work_set: Array[U8] iso) =>
    _working_set = consume work_set

  fun ref process(runner: WorkerRunner[Array[U8] iso, Array[U8] val] ref) =>
    runner.deliver(_working_set)

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
