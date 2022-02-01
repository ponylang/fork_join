use "ponytest"

class \nodoc\ iso _TestEndToEnd is UnitTest
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

    let job = Job[Array[U8] iso, Array[U8] val](
      _EndToEndBuilder,
      _EndToEndGenerator(consume input),
      _EndToEndCollector(h, expected))

    job.start()

class \nodoc\ _EndToEndBuilder is WorkerBuilder[Array[U8] iso, Array[U8] val]
  fun ref apply(): Worker[Array[U8] iso, Array[U8] val] iso^ =>
    _EndToEndWorker

class \nodoc\ _EndToEndGenerator is Generator[Array[U8] iso]
  var _working_set: Array[U8] iso

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

class \nodoc\ _EndToEndCollector is Collector[Array[U8] iso, Array[U8] val]
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

class \nodoc\ _EndToEndWorker is Worker[Array[U8] iso, Array[U8] val]
  var _working_set: Array[U8] val = recover val _working_set.create() end

  fun ref receive(work_set: Array[U8] iso) =>
    _working_set = consume work_set

  fun ref process(runner: WorkerRunner[Array[U8] iso, Array[U8] val] ref) =>
    runner.deliver(_working_set)
