// in your code this `use` statement would be:
// use "fork_join"
use fj = "../../fork_join"
use "random"

actor Main
  new create(env: Env) =>
    fj.Coordinator[USize, String](
      WorkerBuilder,
      Generator,
      Accumulator(env.out))

class WorkerBuilder is fj.WorkerBuilder[USize, String]
  fun ref apply(): fj.WorkerNotify[USize, String] iso^ =>
    USizeToString

class Generator is fj.Generator[USize]
  let _rand: Rand = _rand.create()

  fun ref apply(workers_remaining: USize): USize ? =>
    let x = _rand.next().usize()
    if (x % 1000) == 0 then
      error
    end
    x

class Accumulator is fj.Accumulator[USize, String]
  let _strings: Array[String] = _strings.create()
  let _out: OutStream

  new iso create(out: OutStream) =>
    _out = out

  fun ref collect(accumulator: fj.AccumulatorRunner[USize, String] ref,
    result: String)
  =>
    _strings.push(result)

  fun ref finished() =>
    for s in _strings.values() do
      _out.print(s)
    end

class USizeToString is fj.WorkerNotify[USize, String]
  var _usize: USize = 0

  fun ref receive(work_set: USize) =>
    _usize = work_set

  fun ref process(worker: fj.WorkerRunner[USize, String] ref) =>
    worker.deliver(_usize.string())

