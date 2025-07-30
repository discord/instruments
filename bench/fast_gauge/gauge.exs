Application.ensure_all_started(:instruments)

# Benchee.run(
#   %{
#     "gauge_non_parallel" => fn options ->
#       for v <- 1..100 do
#         Instruments.Statix.gauge("test.gauge", v, options)
#       end
#     end,
#     "fastgauge_non_parallel" => fn options ->
#       for v <- 1..100 do
#         Instruments.FastGauge.gauge("test.gauge", v, options)
#       end
#     end,
#     "fastgauge_multitable_non_parallel" => fn options ->
#       for v <- 1..100 do
#         Instruments.FasterGauge.gauge("test.gauge", v, options)
#       end
#     end
#   },
#   inputs: %{
#     "1. No Options" => [],
#     "2. No Tags" => [sample_rate: 1.0],
#     "3. Empty Tags" => [sample_rate: 1.0, tags: []],
#     "4. One Tag" => [sample_rate: 1.0, tags: ["test:tag"]],
#     "5. Five Tags" => [sample_rate: 1.0, tags: ["test-1:tag", "test-2:tag", "test-3:tag", "test-4:tag", "test-5:tag"]],
#     "6. Ten Tags" => [sample_rate: 1.0, tags: ["test-1:tag", "test-2:tag", "test-3:tag", "test-4:tag", "test-5:tag", "test-6:tag", "test-7:tag", "test-8:tag", "test-9:tag", "test-10:tag"]]
#   },
#   parallel: 1,
#   save: [path: "bench/results/fast_gauge/non_parallel.benchee"]
# )

Benchee.run(
  %{
    "gauge_parallel_8" => fn options ->
      for v <- 1..100 do
        Instruments.Statix.gauge("test.gauge", v, options)
      end
    end,
    "fastgauge_parallel_8" => fn options ->
      for v <- 1..100 do
        Instruments.FastGauge.gauge("test.gauge", v, options)
      end
    end,
    "fastgauge_multitable_parallel_8" => fn options ->
      for v <- 1..100 do
        Instruments.FasterGauge.gauge("test.gauge", v, options)
      end
    end
  },
  inputs: %{
    "1. No Options" => [],
    "2. No Tags" => [sample_rate: 1.0],
    "3. Empty Tags" => [sample_rate: 1.0, tags: []],
    "4. One Tag" => [sample_rate: 1.0, tags: ["test:tag"]],
    "5. Five Tags" => [sample_rate: 1.0, tags: ["test-1:tag", "test-2:tag", "test-3:tag", "test-4:tag", "test-5:tag"]],
    "6. Ten Tags" => [sample_rate: 1.0, tags: ["test-1:tag", "test-2:tag", "test-3:tag", "test-4:tag", "test-5:tag", "test-6:tag", "test-7:tag", "test-8:tag", "test-9:tag", "test-10:tag"]]
  },
  parallel: 8,
  save: [path: "bench/results/fast_gauge/parallel_8.benchee"]
)
