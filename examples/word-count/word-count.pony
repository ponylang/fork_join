// in your code this `use` statement would be:
// use "fork_join"
use fj = "../../fork_join"
use "collections"
use "files"
use "runtime_info"

type WordCounts is Map[String, USize]

actor Main
  new create(env: Env) =>
    try
      let caps =
        recover val FileCaps .> set(FileRead) .> set(FileStat) end
      let fp =
        FilePath(FileAuth(env.root), env.args(1)?, caps)
      let file = recover iso OpenFile(fp) as File end

      let job =
        fj.Job[String, WordCounts iso](
          WorkerBuilder,
          FileReader(consume file),
          WordCountTotaler(env.out),
          SchedulerInfoAuth(env.root))

      job.start()
    else
      env.exitcode(-1)
      env.err.print("Error during setup.")
    end

class WorkerBuilder is fj.WorkerBuilder[String, WordCounts iso]
  """
  Creates SplitAndCount workers.
  """
  fun ref apply(): fj.Worker[String, WordCounts iso] iso^ =>
    SplitAndCount

class SplitAndCount is fj.Worker[String, WordCounts iso]
  """
  Splits input text into words and counts their frequencies.
  """
  var _working_set: String = ""

  fun ref receive(data: String) =>
    _working_set = data

  fun ref process(
    runner: fj.WorkerRunner[String, WordCounts iso] ref)
  =>
    """
    Split input into words, count each, and deliver the result.
    """
    let punctuation =
      """ !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~'" """
    let words_and_counts = recover iso WordCounts end
    for line in _working_set.split("\n").values() do
      let cleaned =
        recover val
          line.lower()
            .> lstrip(punctuation)
            .> rstrip(punctuation)
        end
      for word in cleaned.split(punctuation).values() do
        words_and_counts.upsert(
          word,
          1,
          {(current, provided) => current + provided })
      end
    end

    runner.deliver(consume words_and_counts)

class FileReader is fj.Generator[String]
  """
  Reads lines from a file, one per call.
  """
  let _lines: FileLines
  var _workers: USize = 0

  new iso create(file: File iso) =>
    _lines = (consume file).lines()

  fun ref init(workers: USize) =>
    _workers = workers

  fun ref apply(): String ? =>
    _lines.next()?

class WordCountTotaler is fj.Collector[String, WordCounts iso]
  """
  Merges per-worker word counts and prints the totals.
  """
  var _counts: (WordCounts | None) = None
  let _out: OutStream

  new iso create(out: OutStream) =>
    _out = out

  fun ref collect(
    runner: fj.CollectorRunner[String, WordCounts iso] ref,
    result: WordCounts iso)
  =>
    match \exhaustive\ _counts
    | None =>
      _counts = consume result
    | let counts: WordCounts =>
      for (word, count) in (consume result).pairs() do
        counts.upsert(
          word,
          count,
          {(current, provided) => current + provided })
      end
    end

  fun ref finish() =>
    match \exhaustive\ _counts
    | None =>
      _out.print("No words counted.")
    | let counts: WordCounts =>
      _out.print("Final word counts...")
      for (word, count) in counts.pairs() do
        _out.print(word + ":" + count.string())
      end
    end
