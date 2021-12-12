// in your code this `use` statement would be:
// use "fork_join"
use fj = "../../fork_join"

actor Main
  new create(env: Env) =>
    let array: Array[U8] iso = recover iso [ 201;202;3;4;5;6;7;8;9;10 ] end
    fj.Coordinator[Array[U8] iso, USize](
      WorkerBuilder,
      Generator(consume array),
      Accumulator(env.out))

class WorkerBuilder is fj.WorkerBuilder[Array[U8] iso, USize]
  fun ref apply(): fj.WorkerNotify[Array[U8] iso, USize] iso^ =>
    Adder

class Generator is fj.Generator[Array[U8] iso]
  var _working_set: Array[U8] iso
  var _distribution_set: Array[USize] = _distribution_set.create()

  new iso create(working_set: Array[U8] iso) =>
    _working_set = consume working_set

  fun ref init(workers: USize) =>
    _distribution_set = fj.EvenlySplitDataElements(_working_set.size(), workers)

  fun ref apply(): Array[U8] iso^ ? =>
    if _working_set.size() == 0 then
      error
    end

    let distribution_amount = _distribution_set.shift()?
    (let batch, _working_set) = (consume _working_set).chop(distribution_amount)
    consume batch

class Accumulator is fj.Accumulator[Array[U8] iso, USize]
  var _total: USize = 0
  let _out: OutStream

  new iso create(out: OutStream) =>
    _out = out

  fun ref collect(accumulator: fj.AccumulatorRunner[Array[U8] iso, USize] ref,
    result: USize)
  =>
    _total = _total + result

  fun ref finished() =>
    _out.print(_total.string())

class Adder is fj.WorkerNotify[Array[U8] iso, USize]
  var _working_set: Array[U8] = _working_set.create()

  fun ref receive(work_set: Array[U8] iso) =>
    _working_set = consume work_set

  fun ref process(worker: fj.WorkerRunner[Array[U8] iso, USize] ref) =>
    var total: USize = 0

    for i in _working_set.values() do
      total = total + i.usize()
    end

    worker.deliver(total)
