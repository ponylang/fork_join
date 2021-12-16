primitive EvenlySplitDataElements
  """
  Gives a distribution for X `data_elements` across Y `split_across` buckets.

  Useful to taking things like an Array of data and dividing it up "evenly"
  across a number of workers.

  The return value is an Array of `split_across` length with each bucket being
  the number of `data_elements` that would fall into that bucket. In our
  fork/join use case, that means that each Array bucket is the number of
  data_elements to give to a worker corresponding to the bucket.
  """
  fun apply(data_elements: USize, split_across: USize): Array[USize] iso^ =>
    // If the number data elements were equal to number of workers to split
    // across then each worker would get 1 element.
    // We use division to get a basic value to insert.
    let value = data_elements / split_across
    let a = recover iso Array[USize].init(value, split_across) end
    // Because our data elements will rarely be evenly distributible, we need to
    // assign out the extras as a +1 to each value at the beginning of our
    // array. So for example if there are 5 extras, the first 5 elements in
    // our output array will have 1 added to them.
    var extras = data_elements % split_across
    while extras > 0 do
      extras = extras - 1
      try
        a(extras)? = (a(extras)? + 1)
      end
    end
    consume a
