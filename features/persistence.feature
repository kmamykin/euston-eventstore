Feature: Persistence

  Scenario: a commit is successfully persisted
    Given a commit attempt
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
    
  Scenario: 