keyword_merge = fn input ->
  for _ <- 1..100 do
    case Keyword.get(input, :tags) do
      tags when is_list(tags) ->
        {:test, Keyword.merge(input, tags: Enum.sort(tags))}

      _ ->
        {:test, input}
    end
  end
end

keyword_merge_special = fn input ->
  for _ <- 1..100 do
    case Keyword.get(input, :tags) do
      [] ->
        {:test, input}

      [_] ->
        {:test, input}

      tags when is_list(tags) ->
        {:test, Keyword.merge(input, tags: Enum.sort(tags))}

      _ ->
        {:test, input}
    end
  end
end

keyword_pop_and_put = fn input ->
  for _ <- 1..100 do
    case Keyword.pop(input, :tags) do
      {tags, input} when is_list(tags) ->
        {:test, Keyword.put(input, :tags, Enum.sort(tags))}

      _ ->
        {:test, input}
    end
  end
end

keyword_pop_and_put_special = fn input ->
  for _ <- 1..100 do
    case Keyword.pop(input, :tags) do
      {[], _} ->
        {:test, input}

      {[_], _} ->
        {:test, input}

      {tags, input} when is_list(tags) ->
        {:test, Keyword.put(input, :tags, Enum.sort(tags))}

      _ ->
        {:test, input}
    end
  end
end

keyword_replace = fn input ->
  for _ <- 1..100 do
    case Keyword.get(input, :tags) do
      tags when is_list(tags) ->
        {:test, Keyword.replace!(input, :tags, Enum.sort(tags))}

      _ ->
        {:test, input}
    end
  end
end

keyword_replace_special = fn input ->
  for _ <- 1..100 do
    case Keyword.get(input, :tags) do
      [] ->
        {:test, input}

      [_] ->
        {:test, input}

      tags when is_list(tags) ->
        {:test, Keyword.replace!(input, :tags, Enum.sort(tags))}

      _ ->
        {:test, input}
    end
  end
end


Benchee.run(
  %{
    "Keyword.get/2 + Keyword.merge/2" => &keyword_merge.(&1),
    "Keyword.pop/2 + Keyword.put/3" => &keyword_pop_and_put.(&1),
    "Keyword.get/2 + Keyword.replace!/3" => &keyword_replace.(&1),
    "Keyword.get/2 + Keyword.merge/2 with Special Casing" => &keyword_merge_special.(&1),
    "Keyword.pop/2 + Keyword.put/3 with Special Casing" => &keyword_pop_and_put_special.(&1),
    "Keyword.get/2 + Keyword.replace!/3 with Special Casing" => &keyword_replace_special.(&1),
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
