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

  fun ref apply(workers_remaining: USize): (USize, Bool) =>
    (_rand.next().usize(), true)

class Accumulator is fj.Accumulator[String]
  let _strings: Array[String] = _strings.create()
  let _out: OutStream

  new iso create(out: OutStream) =>
    _out = out

  fun ref collect(result: String) =>
    _strings.push(result)

  fun ref finished() =>
    for s in _strings.values() do
      _out.print(s)
    end

class USizeToString is fj.WorkerNotify[USize, String]
  var _usize: USize = 0

  fun ref init(worker: fj.Worker[USize, String] ref, work_set: USize) =>
    _usize = work_set

  fun ref work(worker: fj.Worker[USize, String] ref) =>
    worker.done(_usize.string())

