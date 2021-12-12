// TODO: needs class level documentation
actor WorkerRunner[Input: Any #send, Output: Any #send]
  let _coordinator: Coordinator[Input, Output]
  let _accumulator: AccumulatorRunner[Input, Output]
  let _notify: Worker[Input, Output]
  var _running: Bool = false
  var _early_termination_requested: Bool = false

  new create(coordinator: Coordinator[Input, Output],
    accumulator: AccumulatorRunner[Input, Output],
    notify: Worker[Input, Output] iso)
  =>
    _coordinator = coordinator
    _accumulator = accumulator
    _notify = consume notify

  fun ref deliver(result: Output) =>
    """
    Called to send a result to the accumulator and request additional work from
    the coordinator.
    """
    _accumulator._receive(consume result)
    _coordinator._request(this)

  fun ref yield() =>
    """
    Called to have the worker yield the CPU and continue later.
    """
    _run_again()

  be _receive(batch: Input) =>
    """
    Behavior to receive data from the generator.
    """
    if not _early_termination_requested then
      _notify.receive(consume batch)
      _notify.process(this)
    end

  be _run_again() =>
    """
    Message sent from a worker to itself to restart working after yielding.
    """
    if not _early_termination_requested then
      _notify.process(this)
    end

  be _terminate() =>
    """
    Request to stop processing. No future work will be done by this worker once
    the message is processed.
    """
    _early_termination_requested = true
    _coordinator._worker_finished(this)
