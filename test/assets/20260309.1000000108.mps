@mps[project-alpha]{
  @task[backend, status: open]{ Implement OAuth endpoint }
  @task[frontend, status: done]{ Design login page layout }
  @mps[sub-milestone]{
    @task[backend, status: open]{ Write API integration tests }
    @note[backend]{ Remember to add rate limiting headers }
  }
}

@note[retrospective]{
  Good sprint overall — auth architecture is solid
}

@log[work, start: 09:00, end: 17:30]{
  Full work day on project-alpha
}
