"""
# Fork/join package

fork/join package is a parallel processing framework. It handles much of the
plumbing required to distribute a data processing tasks across multiple actors.

`fork_join` is used by creating a [`Job`](/fork_join/fork_join-Job/) and
then sending a `start` message to begin processing.

```pony
use fj = "fork_join"
use "runtime_info"

actor Main
  new create(env: Env) =>
    let job = fj.Job[USize, String](
      WorkerBuilder,
      Generator,
      StringCollector(env.out),
      SchedulerInfoAuth(env.root))

    job.start()
```

`Job` takes 3 classes that are implemented by library users to implement
functionality and in turn, the `fork_join` library orchestrates the interactions
amongst the user supplied classes.

`Job` requires:

- a `WorkerBuilder`
- a `Generator`
- a `Collector`

In addition to the 3 classes required to start a `Job`, users of `fork_join`
will need to create 1 additional class; one that provides `Worker`.
Additionally, a `SchedulerInfoAuth` auth is required to allow the library to
pick an optimum amount of workers to create based on the number of Pony runtime
scheduler threads available.

## User supplied `fork_join` components

To create a `fork_join` job, users must provide an implementation for 4 different interfaces supplied by the `fork_join` library.

### Worker

[`Worker`](/fork_join/fork_join-Worker/) instances are responsible for taking
input data and an output that will be sent to a `Collector` instance for final
tabulation.

### WorkerBuilder

A [`WorkerBuilder`](/fork_join/fork_join-WorkerBuilder/) is a factory for
creating instances of `Worker`. This component is used when setting up a job.
After that, only the other 3 classes are used during processing runtime.

### Generator

A [`Generator`](/fork_join/fork_join-Generator/) creates data on demand which
will be sent to various `Worker` instances where the data will be processed.

### Collector

A [`Collector`](/fork_join/fork_join-Collector/) is the final step in the
processing pipeline. The `Collector` instance receives incremental results
from `Worker` instances and creates a running tabulation.

When the job is finished, a `finish` message will be sent to the collector so
it can take whatever steps are required to communicate the final calculation
to the rest of the program or user.

## Example usage

A variety of example application are available in the
[examples folder](https://github.com/ponylang/fork_join/tree/main/examples) in
the fork_join repository on GitHub.

Below is a simple example program with a generator that creates random numbers,
workers that pass the numbers through without any procesing, and a collector
that stores the numbers in an array until the job is finished. At this point
the collector will print the collected numbers to standard output.

The job finishes when the generator indicates that it is out of data by
triggering an `error` if the random number it generates is evenly divisible by
1000.

```pony
use fj = "fork_join"
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
```

## `Job` lifecycle

Once a `Job` is created, nothing will happen until it is sent a `start`
message. Once the job has started, it will run until the data generator runs
out of data (or never if the generator can create an infinite supply of data).

A job can be ended early by:

- Sending a [`terminate`](/fork_join/fork_join-Job/#terminate) message to the `Job` instance
- Calling `terminate` from the [`collect`](/fork_join/fork_join-Collector/#collect) method of the `Collector`
"""
