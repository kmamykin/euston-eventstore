Feature: Persistence

  @wip
  Scenario: a commit is successfully persisted
    Given a persistence engine
    And a commit attempt
    When the commit is persisted
    Then it should be possible to read the commit from the stream
    And the commit should be added to the set of undispatched commites
    And the stream should exist in the list of streams to snapshot
    And the events should be serialized and deserialized correctly

  Scenario: reading from a specific revision
    Given a sequence of commits
    When a specific revision is loaded
    Then the stream starts from the commit which contains the min revision specified
    And the stream ends with the commit which contains the max revision specified
    
  Scenario: committing a stream with the same revision
    Given a stream id
    And a persistence engine A
    And a persistence engine B
    And a stream is committed with that stream id on persistence engine A
    When a stream is committed with that stream id on persistence engine B
    Then a concurrency exception is raised

  Scenario: attempt to overwrite a committed sequence
    Given a stream id
    And a persistence engine
    And the persistence engine persists a new commit with that stream id
    When the persistence engine attempts to persist a new commit with that stream id
    Then a concurrency exception is raised
    