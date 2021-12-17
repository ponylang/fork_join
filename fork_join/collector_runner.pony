// TODO: top level documentation
actor CollectorRunner[Input: Any #send, Output: Any #send]
  var _terminating: Bool = false
  let _coordinator: Coordinator[Input, Output]
  let _collector: Collector[Input, Output]

  new create(collector: Collector[Input, Output] iso,
    coordinator: Coordinator[Input, Output])
  =>
    _collector = consume collector
    _coordinator = coordinator

  fun ref terminate() =>
    """
    Called from the user supplied collector to terminate processing before the
    generator is out of data.
    """
    if not _terminating then
      _terminating = true
      _coordinator._terminate()
    end

  be _receive(result: Output) =>
    """
    Receive data from a worker.
    """
    _collector.collect(this, consume result)

  be _finish() =>
    """
    Message delivered when all workers are done processing and the collector
    can do any final work that needs to be done before the job ends.
    """
    _collector.finish()
