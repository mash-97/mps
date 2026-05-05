@mps[sprint-planning]{
  @task[backend, status: open]{
    Design the user authentication API
  }
  @task[backend, status: done]{
    Set up the PostgreSQL schema
  }
  @task[frontend, status: open]{
    Build the login form component
  }
  @note[backend]{
    JWT tokens expire in 24h — remember to add refresh token flow
  }
}

@log[work, start: 09:00, end: 12:30]{
  Morning deep work: authentication architecture review
}

@reminder[at: 3pm]{
  Sync with the frontend team about auth token format
}

@task[devops, status: open]{
  Set up CI/CD pipeline for staging environment
}

@note{
  Great progress today. The schema design took longer than expected but the
  decisions we made about normalization will pay off later.
}
