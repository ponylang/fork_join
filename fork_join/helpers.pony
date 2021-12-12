primitive EvenlySplitDataElements
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
