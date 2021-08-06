Feature: Alerting for machine-api

  # @author jhou@redhat.com
  # @case_id OCP-26248
  @admin
  @destructive
  Scenario: Alert should be fired when operator is down
    Given I switch to cluster admin pseudo user

    # scale down cvo and operators
    When I run the :scale admin command with:
      | resource | deployment                |
      | name     | cluster-version-operator  |
      | replicas | 0                         |
      | n        | openshift-cluster-version |
    Then the step should succeed
    And I register clean-up steps:
    """
    When I run the :scale admin command with:
      | resource | deployment                |
      | name     | cluster-version-operator  |
      | replicas | 1                         |
      | n        | openshift-cluster-version |
    Then the step should succeed
    """
    When I run the :scale admin command with:
      | resource | deployment  |
      | name     | machine-api-operator  |
      | replicas | 0           |
      | n        | openshift-machine-api |
    Then the step should succeed
    And I register clean-up steps:
    """
    When I run the :scale admin command with:
      | resource | deployment  |
      | name     | machine-api-operator  |
      | replicas | 1           |
      | n        | openshift-machine-api |
    Then the step should succeed
    """

    Given I wait up to 180 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?                  |
      | query | ALERTS{alertname="MachineAPIOperatorDown"} |
    Then the step should succeed
    And the expression should be true> @result[:parsed]["data"]["result"][0]["metric"]["alertstate"] =~ /pending|firing/
    """
