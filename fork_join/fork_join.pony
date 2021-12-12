use "collections"
use @ponyint_sched_cores[I32]()

actor Coordinator[Input: Any #send, Output: Any #send]
  let _worker_builder: WorkerBuilder[Input, Output]
  let _generator: Generator[Input]
  let _accumulator: AccumulatorRunner[Input, Output]
  let _workers: SetIs[WorkerRunner[Input, Output]] = _workers.create()
  let _max_workers: USize

  new create(worker_builder: WorkerBuilder[Input, Output] iso,
    generator: Generator[Input] iso,
    accumulator: Accumulator[Input, Output] iso,
    max_workers: USize = 0)
  =>
    _worker_builder = consume worker_builder
    _generator = consume generator
    _accumulator = AccumulatorRunner[Input, Output](consume accumulator, this)

    _max_workers = if max_workers > 0 then
      max_workers
    else
      @ponyint_sched_cores().usize()
    end

    _generator.init(_max_workers)

    var mw = _max_workers
    while true do
      // create worker
      let w = WorkerRunner[Input, Output](this, _accumulator, _worker_builder())
      _workers.set(w)

      // request data for the worker
      _request(w)

      // Run down max workers
      mw = mw - 1
      if mw == 0 then break end
    end

  be _request(worker: WorkerRunner[Input, Output]) =>
    if _workers.contains(worker) then
      try
        let batch = _generator()?
        worker._receive(consume batch)
      else
        // there's no additional work to do
        _workers.unset(worker)
        // TODO: maybe this should be somewhere else
        if _workers.size() == 0 then
          _accumulator._finish()
        end
      end
    else
      // TODO: this should never happen
      None
    end

  be _terminate() =>
    // send message to each worker to stop working
    for worker in _workers.values() do
      worker._terminate()
    end

  be _worker_finished(worker: WorkerRunner[Input, Output]) =>
    """
    A worker ended early as requested by coordinator. Remove it from list.
    """
    _workers.unset(worker)
    // TODO: maybe this should be somewhere else
    if _workers.size() == 0 then
      _accumulator._finish()
    end

actor AccumulatorRunner[Input: Any #send, Output: Any #send]
  let _coordinator: Coordinator[Input, Output]
  let _accumulator: Accumulator[Input, Output]

  new create(accumulator: Accumulator[Input, Output] iso,
    coordinator: Coordinator[Input, Output])
  =>
    _accumulator = consume accumulator
    _coordinator = coordinator

  be _receive(result: Output) =>
    _accumulator.collect(this, consume result)

  be _finish() =>
    _accumulator.finished()

  fun ref finish() =>
    _coordinator._terminate()

interface WorkerBuilder[Input: Any #send, Output: Any #send]
  fun ref apply(): Worker[Input, Output] iso^
    """
    Creates a new worker
    """

interface Generator[A: Any #send]
  fun ref init(workers: USize)
    """
    Called before the first time the generator is called. Allows the generator
    to distribute work based on the number of workers available.
    """

  fun ref apply(): A^ ?
    """
    Called each time a worker needs data.

    If not additional data is available, `error` should be called.
    """

interface Accumulator[Input: Any #send, Output: Any #send]
  fun ref collect(
    accumulator: AccumulatorRunner[Input, Output] ref,
    result: Output)
    """
    Called when a worker results are received from a worker.

    If you need to end processing early, you can call `finish` on `accumulator`.
    Otherwise, the job will continue.
    """

  fun ref finished()
    """
    Called when all workers have reported in their results
    """

primitive EvenlySplitDataElements
  fun apply(data_elements: USize, split_across: USize): Array[USize] iso^ =>
    // If the number data elements were equal to number of workers to split
    // across then each worker would get 1 element.
    // We use division to get a basic value to insert.
    let value = data_elements / split_across
    let a = recover iso Array[USize].init(value, split_across) end
    // Because our data elements will rarely be evenly distributible, we need to
    // assign out the extras as a +1 to each value at the beginning of our
    // array. So for example if there are 5 extras, the first 5 elements in
    // our output array will have 1 added to them.
    var extras = data_elements % split_across
    while extras > 0 do
      extras = extras - 1
      try
        a(extras)? = (a(extras)? + 1)
      end
    end
    consume a
