@task{
  outer task
  @log{
    nested log inside task
  }
  @note{
    nested note inside task
  }
}

@mps{
  @task[work]{
    task inside mps block
  }
  @mps{
    @task{
      deeply nested task
    }
  }
}
