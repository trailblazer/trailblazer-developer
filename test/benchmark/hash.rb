require "benchmark/ips"


value = {
  a: 1,
  b: 2,
  c: 3,
  d: {
    e: 1,
    f: {
      g: 1
    }
  }
}

Benchmark.ips do |x|

  # Typical mode, runs the block as many times as it can
  x.report("inspect") { value.inspect }
  x.report("hash") { value.hash }


  # Compare the iterations per second of the various reports!
  x.compare!
end
