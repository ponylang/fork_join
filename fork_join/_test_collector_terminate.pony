use "ponytest"

class \nodoc\ iso _TestCollectorTerminate is UnitTest
  """
  Tests that when `terminate` is called by a collector that the job will
  eventually shutdown. We test this by waiting on the collector to receive a
  `finish` call after it has signalled to its runner to stop. This works
  because the generator has no end and will keep producing data forever. If
  terminate didn't work then the job should continue running.

  This test assumes that `finish` isn't called incorrectly before a job is done. We are reliant on the end-to-end test to provide give us a some
  provability of that axiom.

  We don't test the results expected as there's not a deterministic number of
  results that will be collected despite our always sending the termination
  request at the same time for each run.
  """
  fun name(): String =>
    "fork_join/CollectorTerminate"

  fun apply(h: TestHelper) =>
    h.long_test(1_000_000_000)
    h.expect_action("collector.finish()")

    let job = Job[U8, U8](
      _CollectorTerminateBuilder,
      _CollectorTerminateGenerator,
      _CollectorTerminateCollector(h))

    job.start()

class \nodoc\ _CollectorTerminateBuilder is WorkerBuilder[U8, U8]
  fun ref apply(): Worker[U8, U8] iso^ =>
    _CollectorTerminateWorker

class \nodoc\ _CollectorTerminateGenerator is Generator[U8]
  """
  Generator never runs out, this allows us to test that termination triggered
  via a Collector works.
  """
  var _value_to_send: U8 = 0

  fun ref init(workers: USize) =>
    None

  fun ref apply(): U8 =>
    _value_to_send = _value_to_send + 1

class \nodoc\ _CollectorTerminateCollector is Collector[U8, U8]
  """
  Collector that will ask for termination of the job after it has received
  10 results. If termination doesn't work, then `finish` should never be called
  which would cause the test to fail.
  """
  var _results_received: USize = 0
  let _helper: TestHelper

  new iso create(helper: TestHelper) =>
    _helper = helper

  fun ref collect(runner: CollectorRunner[U8, U8] ref,
    result: U8)
  =>
    _results_received = _results_received + 1

    if _results_received == 10 then
      runner.terminate()
    end

  fun ref finish() =>
    _helper.complete_action("collector.finish()")

class \nodoc\ _CollectorTerminateWorker is Worker[U8, U8]
  var _working_set: U8 = 0

  fun ref receive(work_set: U8) =>
    _working_set = work_set

  fun ref process(runner: WorkerRunner[U8, U8] ref) =>
    runner.deliver(_working_set)
