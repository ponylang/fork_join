// in your code this `use` statement would be:
// use "fork_join"
use fj = "../../fork_join"
use "collections"
use "files"

type WordCounts is Map[String, USize]

actor Main
  new create(env: Env) =>
    try
      let caps = recover val FileCaps.>set(FileRead).>set(FileStat) end
      let fp = FilePath(env.root as AmbientAuth, env.args(1)?, caps)
      let file = recover iso OpenFile(fp) as File end

      fj.Coordinator[String, WordCounts iso](
        WorkerBuilder,
        FileReader(consume file),
        WordCountTotaler(env.out))
    else
      env.exitcode(-1)
      env.err.print("Error during setup.")
    end

class WorkerBuilder is fj.WorkerBuilder[String, WordCounts iso]
  fun ref apply(): fj.Worker[String, WordCounts iso] iso^ =>
    SplitAndCount

class SplitAndCount is fj.Worker[String, WordCounts iso]
  var _working_set: String = ""

  fun ref receive(data: String) =>
    _working_set = data

  fun ref process(
    runner: fj.WorkerRunner[String, WordCounts iso] ref)
  =>
    let punctuation = """ !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~‘“ """
    let words_and_counts = recover iso WordCounts end
    for line in _working_set.split("\n").values() do
      let cleaned =
        recover val line.lower().>lstrip(punctuation)
          .>rstrip(punctuation) end
      for word in cleaned.split(punctuation).values() do
        words_and_counts.upsert(word,
          1,
          {(current, provided) => current + provided})
      end
    end

    runner.deliver(consume words_and_counts)

class FileReader is fj.Generator[String]
  let _lines: FileLines
  var _workers: USize = 0

  new iso create(file: File iso) =>
    _lines = (consume file).lines()

  fun ref init(workers: USize) =>
    _workers = workers

  fun ref apply(): String ? =>
    _lines.next()?

class WordCountTotaler is fj.Collector[String, WordCounts iso]
  var _counts: (WordCounts | None) = None
  let _out: OutStream

  new iso create(out: OutStream) =>
    _out = out

  fun ref collect(runner: fj.CollectorRunner[String, WordCounts iso] ref,
    result: WordCounts iso)
  =>
    match _counts
    | None =>
      // We haven't gotten any counts yet, instead of copying the map, let's
      // just keep the first one as our base to build upon
      _counts = consume result
    | let counts: WordCounts =>
      for (word, count) in (consume result).pairs() do
        counts.upsert(word,
        count,
        {(current, provided) => current + provided})
      end
    end

  fun ref finish() =>
    match _counts
    | None =>
      _out.print("No words counted.")
    | let counts: WordCounts =>
      _out.print("Final word counts...")
      for (word, count) in counts.pairs() do
        _out.print(word + ":" + count.string())
      end
    end

