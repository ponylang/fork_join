use "collections"
use @ponyint_sched_cores[I32]()

actor Coordinator[Input: Any #send, Output: Any #send]
  let _worker_builder: WorkerBuilder[Input, Output]
  let _generator: Generator[Input]
  let _accumulator: Accumulator[Output]
  let _workers: SetIs[Worker[Input, Output]] = _workers.create()

  new create(worker_builder: WorkerBuilder[Input, Output] iso,
    generator: Generator[Input] iso,
    accumulator: Accumulator[Output] iso,
    max_workers: USize = 0)
  =>
    _worker_builder = consume worker_builder
    _generator = consume generator
    _accumulator = consume accumulator

    var mw = if max_workers > 0 then
      max_workers
    else
      @ponyint_sched_cores().usize()
    end

    while true do
      // Determine if there is a batch for next worker, if not, end early
      match _generator(mw)
      | let batch: Array[Input] iso =>
        // create worker
        let w = Worker[Input, Output](this, _worker_builder())
        _workers.set(w)

        // start the worker
        w.start(consume batch)

        // Run down max workers
        mw = mw - 1
        if mw == 0 then break end
      | NoMoreBatches =>
        // There's no additional batches so, let's stop creating workers.
        break
      end
    end

  // TODO: should be private
  be done(worker: Worker[Input, Output], result: Output) =>
    _accumulator.collect(consume result)
    if _workers.contains(worker) then
      _workers.unset(worker)
      if _workers.size() == 0 then
        _accumulator.finished()
      end
    end

interface WorkerBuilder[Input: Any #send, Output: Any #send]
  fun ref apply(): WorkerNotify[Input, Output] iso^
    """
    Creates a new worker
    """

interface Generator[A: Any #send]
  fun ref apply(workers_remaining: USize): (Array[A] iso^ | NoMoreBatches)
    """
    Called once per-worker to allow creation of a working set for the given
    worker. If no additional work is left to give out, returning
    `NoMoreBatches` will end worker creation.

    `workers_remaining` is the number of workers left waiting for work.
    """

primitive NoMoreBatches

interface Accumulator[A: Any #send]
  fun ref collect(result: A)
    """
    Called when a worker has finished working and has a result to be
    "accumulated"
    """

  fun ref finished()
    """
    Called when all workers have reported in their results
    """

actor Worker[Input: Any #send, Output: Any #send]
  let _coordinator: Coordinator[Input, Output]
  let _notify: WorkerNotify[Input, Output]
  var _running: Bool = false

  new create(coordinator: Coordinator[Input, Output],
    notify: WorkerNotify[Input, Output] iso)
  =>
    _coordinator = coordinator
    _notify = consume notify

  be start(batch: Array[Input] iso) =>
    if not _running then
      _running = true
      _notify.init(this, consume batch)
      _notify.work(this)
    end

  be _run_again() =>
    // should do some guard here
    _notify.work(this)

  fun ref done(result: Output) =>
    """
    Called to stop processing and return a result
    """
    _coordinator.done(this, consume result)

  fun ref yield() =>
    """
    Called to have the worker yield the CPU and continue later.
    """
    _run_again()

interface WorkerNotify[Input: Any #send, Output: Any #send]
  fun ref init(worker: Worker[Input, Output] ref, work_set: Array[Input] iso)
    """
    Called when a worker first starts working. Followed by a called to `work`.
    `work_set` contains the initial input set for this worker to use as the
    basis for processing.
    """

  fun ref work(worker: Worker[Input, Output] ref)
    """
    Called to get the Worker to do work. Long running workers can give control
    of the CPU back by calling `yield` on `worker`. `work` will then be called
    again at some point in the future to continue working.

    When the worker has a final value to send back to the coordinator, it should
    call `done` on the `worker`.
    """
