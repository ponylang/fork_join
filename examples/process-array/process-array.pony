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

  new iso create(working_set: Array[U8] iso) =>
    _working_set = consume working_set

  fun ref apply(workers_remaining: USize): (Array[U8] iso^, Bool) =>
    //if _working_set.size() == 0 then
    //  return NoMoreBatches
    //end

    let b = if workers_remaining > 1 then
      let bs = if workers_remaining > _working_set.size() then
        1
      else
        _working_set.size() / workers_remaining
      end

      (let b', _working_set) = (consume _working_set).chop(bs)
      consume b'
    else
      // This is the last worker, give it the remaining working set
      _working_set = recover iso Array[U8] end
    end
    (consume b, _working_set.size() != 0)

class Accumulator is fj.Accumulator[USize]
  var _total: USize = 0
  let _out: OutStream

  new iso create(out: OutStream) =>
    _out = out

  fun ref collect(result: USize) =>
    _total = _total + result

  fun ref finished() =>
    _out.print(_total.string())

class Adder is fj.WorkerNotify[Array[U8] iso, USize]
  var _working_set: Array[U8] = _working_set.create()

  fun ref init(worker: fj.Worker[Array[U8] iso, USize] ref, work_set: Array[U8] iso) =>
    _working_set = consume work_set

  fun ref work(worker: fj.Worker[Array[U8] iso, USize] ref) =>
    var total: USize = 0

    for i in _working_set.values() do
      total = total + i.usize()
    end

    worker.done(total)
