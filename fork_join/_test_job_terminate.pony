use "ponytest"
use "runtime_info"

class \nodoc\ iso _TestJobTerminate is UnitTest
  """
  Tests that when a `terminate` message is sent to a job that the job will
  eventually shutdown. We test this by waiting on the collector to receive a
  `finish` indicating that the job has completed. This works because the
  generator has no end and will keep producing data forever. If terminate
  didn't work then the job should continue running.

  This test assumes that `finish` isn't called incorrectly before a job is done. We are reliant on the end-to-end test to provide give us a some
  provability of that axiom.

  We don't test the results expected as there's not a deterministic number of
  results that will be collected despite our always sending the termination
  request at the same time for each run.
  """
  fun name(): String =>
    "fork_join/JobTerminate"

  fun apply(h: TestHelper) =>
    h.long_test(1_000_000_000)
    h.expect_action("collector.finish()")

    let job = Job[U8, U8](
      _JobTerminateBuilder,
      _JobTerminateGenerator,
      _JobTerminateCollector(h),
      SchedulerInfoAuth(h.env.root))

    job.start()
    job.terminate()

class \nodoc\ _JobTerminateBuilder is WorkerBuilder[U8, U8]
  fun ref apply(): Worker[U8, U8] iso^ =>
    _JobTerminateWorker

class \nodoc\ _JobTerminateGenerator is Generator[U8]
  """
  Generator never runs out, this allows us to test that termination triggered
  via a message send to Job works.
  """
  var _value_to_send: U8 = 0

  fun ref init(workers: USize) =>
    None

  fun ref apply(): U8 =>
    _value_to_send = _value_to_send + 1

class \nodoc\ _JobTerminateCollector is Collector[U8, U8]
  """
  Test collector that awaits a `finish` call to indicate that termination at the
  job level works correctly.
  """
  let _helper: TestHelper

  new iso create(helper: TestHelper) =>
    _helper = helper

  fun ref collect(runner: CollectorRunner[U8, U8] ref,
    result: U8)
  =>
    None

  fun ref finish() =>
    _helper.complete_action("collector.finish()")

class \nodoc\ _JobTerminateWorker is Worker[U8, U8]
  var _working_set: U8 = 0

  fun ref receive(work_set: U8) =>
    _working_set = work_set

  fun ref process(runner: WorkerRunner[U8, U8] ref) =>
    runner.deliver(_working_set)
