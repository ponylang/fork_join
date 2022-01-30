"""
# Fork/join package

fork/join package is a parallel processing framework. It handles much of the
plumbing required to distribute a data processing tasks across multiple actors.
Users of required to implement 4 different interfaces that plug into fork/join
supplied actors.

The framework orchestrates

Input data generator.

1 or more workers.

Collector to accumulate results and when all workers are finished, do something
with the final results.

"""
