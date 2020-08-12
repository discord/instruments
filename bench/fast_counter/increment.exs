Application.ensure_all_started(:instruments)

Benchee.run(
  %{
    "increment" => fn options ->
      for _ <- 1..100 do
        Instruments.FastCounter.increment("test.counter", 1, options)
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
  }
)
