// in your code this `use` statement would be:
// use "fork_join"
use fj = "../../fork_join"
use "random"
use "runtime_info"

actor Main
  new create(env: Env) =>
    let job = fj.Job[USize, String](
      WorkerBuilder,
      Generator,
      StringCollector(env.out),
      SchedulerInfoAuth(env.root))
    job.start()

class WorkerBuilder is fj.WorkerBuilder[USize, String]
  fun ref apply(): fj.Worker[USize, String] iso^ =>
    USizeToString

class Generator is fj.Generator[USize]
  let _rand: Rand = _rand.create()

  fun ref init(workers: USize) =>
    None

  fun ref apply(): USize ? =>
    let x = _rand.next().usize()
    if (x % 1000) == 0 then
      error
    end
    x

class StringCollector is fj.Collector[USize, String]
  let _strings: Array[String] = _strings.create()
  let _out: OutStream

  new iso create(out: OutStream) =>
    _out = out

  fun ref collect(runner: fj.CollectorRunner[USize, String] ref,
    result: String)
  =>
    _strings.push(result)

  fun ref finish() =>
    for s in _strings.values() do
      _out.print(s)
    end

class USizeToString is fj.Worker[USize, String]
  var _usize: USize = 0

  fun ref receive(work_set: USize) =>
    _usize = work_set

  fun ref process(runner: fj.WorkerRunner[USize, String] ref) =>
    runner.deliver(_usize.string())

