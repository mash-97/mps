@task[work, release, status: done]{
  Tag v1.0.0 and push to RubyGems
}

@task[work, status: done]{
  Write release notes
}

@task[work, status: open]{
  Update the project README with v1 features
}

@log[work, start: 10:00, end: 14:00]{
  Release day — gem build, tagging, publishing
}

@log[work, start: 15:00, end: 17:00]{
  Post-release: responding to early user feedback
}

@note[release]{
  v1.0.0 ships with: schema DSL, RefResolver, element mutation,
  CLI modularization, Query/Presenter extraction. Clean and fast.
}

@mps[retrospective]{
  @note{
    What went well: the schema DSL made adding attributes trivial.
    The class_eval command pattern is clean and extensible.
  }
  @note{
    What to improve: need position-tracking in the parser for
    robust rewrite without first-match-only limitation.
  }
  @task[status: open]{
    Plan v1.1 scope — position tracking, SQLite index
  }
}

@reminder[at: 9am]{
  Tweet about the release
}
