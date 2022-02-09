actor WorkerRunner[Input: Any #send, Output: Any #send]
  """
  `WorkerRunner` is responsible for delivering data to
  [Worker](/fork_join/fork_join-Worker/) instances for processing and for coordinating
  the job lifecycle with other `fork_join` library actors.
  """
  let _coordinator: _Coordinator[Input, Output]
  let _collector: CollectorRunner[Input, Output]
  let _notify: Worker[Input, Output]
  var _running: Bool = false
  var _early_termination_requested: Bool = false

  new create(coordinator: _Coordinator[Input, Output],
    collector: CollectorRunner[Input, Output],
    notify: Worker[Input, Output] iso)
  =>
    _coordinator = coordinator
    _collector = collector
    _notify = consume notify

  fun ref deliver(result: Output) =>
    """
    Called to send a result to the collector and request additional work from
    the coordinator.
    """
    _collector._receive(consume result)
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
