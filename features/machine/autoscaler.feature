Feature: Cluster Autoscaler Tests

  # @author jhou@redhat.com
  # @case_id OCP-28108
  @admin
  @destructive
  Scenario: Cluster should automatically scale up and scale down with clusterautoscaler deployed
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I store the number of machines in the :num_to_restore clipboard
    And admin ensures node number is restored to "<%= cb.num_to_restore %>" after scenario

    Given I clone a machineset named "machineset-clone"
    And admin ensures "machineset-clone" machineset is deleted after scenario

    # Create clusterautoscaler
    Given I use the "openshift-machine-api" project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/cluster-autoscaler.yml |
    Then the step should succeed
    And admin ensures "default" clusterautoscaler is deleted after scenario
    And 1 pods become ready with labels:
      | cluster-autoscaler=default,k8s-app=cluster-autoscaler |

    # Create machineautoscaler
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest                 |
      | ["spec"]["minReplicas"]            | 1                       |
      | ["spec"]["maxReplicas"]            | 3                       |
      | ["spec"]["scaleTargetRef"]["name"] | <%= machine_set.name %> |
    Then the step should succeed
    And admin ensures "maotest" machineautoscaler is deleted after scenario

    # Create workload
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/autoscaler-auto-tmpl.yml |
    Then the step should succeed

    # Verify machineset has scaled
    Given I wait up to 60 seconds for the steps to pass:
    """
    the expression should be true> machine_set.desired_replicas(cached: false) == 3
    """
    Then the machineset should have expected number of running machines

    # Delete workload
    Given admin ensures "workload" job is deleted from the "openshift-machine-api" project
    # Check cluster auto scales down
    And I wait up to 120 seconds for the steps to pass:
    """
    the expression should be true> machine_set.desired_replicas(cached: false) == 1
    """
    Then the machineset should have expected number of running machines

  # @author zhsun@redhat.com
  # @case_id OCP-23745
  @admin
  @destructive
  Scenario: Delete machineautoscaler related machineset doesn't exist
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I store the number of machines in the :num_to_restore clipboard
    And admin ensures node number is restored to "<%= cb.num_to_restore %>" after scenario

    Given I use the "openshift-machine-api" project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest |
      | ["spec"]["minReplicas"]            | 1       |
      | ["spec"]["maxReplicas"]            | 3       |
      | ["spec"]["scaleTargetRef"]["name"] | invalid |
    Then the step should succeed
    And admin ensures "maotest" machineautoscaler is deleted after scenario
    When I run the :delete admin command with:
      | object_type       | machineautoscaler |
      | object_name_or_id | maotest           |
    Then the step succeeded
    
    
  # @author zhsun@redhat.com
  # @case_id OCP-20108
  @admin
  @destructive
  Scenario: Cluster-autoscaler should balance similiar node groups between zones
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user

    Given I store the number of machines in the :num_to_restore clipboard
    And admin ensures node number is restored to "<%= cb.num_to_restore %>" after scenario

    Given I clone a machineset named "machineset-clone"
    And admin ensures "machineset-clone" machineset is deleted after scenario
    Given I clone a machineset named "machineset-clone1"
    And admin ensures "machineset-clone1" machineset is deleted after scenario
    
    # Create clusterautoscaler
    Given I use the "openshift-machine-api" project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/cluster-autoscaler.yml" replacing paths:
      | ["spec"]["balanceSimilarNodeGroups"] | true |
      | ["spec"]["minReplicas"]              | 1    |
    Then the step should succeed
    And admin ensures "default" clusterautoscaler is deleted after scenario
    And 1 pods become ready with labels:
      | cluster-autoscaler=default,k8s-app=cluster-autoscaler |

    # Create machineautoscaler
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest          |
      | ["spec"]["minReplicas"]            | 1                |
      | ["spec"]["maxReplicas"]            | 3                |
      | ["spec"]["scaleTargetRef"]["name"] | machineset-clone |
    Then the step should succeed
    And admin ensures "maotest" machineautoscaler is deleted after scenario
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest1          |
      | ["spec"]["minReplicas"]            | 1                 |
      | ["spec"]["maxReplicas"]            | 3                 |
      | ["spec"]["scaleTargetRef"]["name"] | machineset-clone1 |
    Then the step should succeed
    And admin ensures "maotest1" machineautoscaler is deleted after scenario

    # Create workload
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cloud/autoscaler-auto-tmpl.yml |
    Then the step should succeed
    And admin ensures "workload" job is deleted after scenario

    # Verify machineset has scaled
    Given I wait for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %> |  
    Then the step should succeed
    And the output should contain:
      | Splitting scale-up between 2 similar node groups |
    """

    Given I use the "machineset-clone" machineset
    And I wait up to 60 seconds for the steps to pass:
    """
    the expression should be true> machine_set.desired_replicas(cached: false) == 3
    """
    Then the machineset should have expected number of running machines

    Given I use the "machineset-clone1" machineset
    And I wait up to 60 seconds for the steps to pass:
    """
    the expression should be true> machine_set.desired_replicas(cached: false) == 3
    """
    Then the machineset should have expected number of running machines  

    And I wait for the steps to pass:
    """
    Given I store the number of machines in the :num_add_workload clipboard
    Then the expression should be true> cb.num_add_workload == cb.num_to_restore + 6
    """

    # Delete workload
    Given admin ensures "workload" job is deleted from the "openshift-machine-api" project
 
    # Check cluster auto scales down
    Given I use the "machineset-clone" machineset
    And I wait up to 120 seconds for the steps to pass:
    """
    the expression should be true> machine_set.desired_replicas(cached: false) == 1
    """
    Then the machineset should have expected number of running machines

    Given I use the "machineset-clone1" machineset
    And I wait up to 120 seconds for the steps to pass:
    """
    the expression should be true> machine_set.desired_replicas(cached: false) == 1
    """
    Then the machineset should have expected number of running machines
    And I wait for the steps to pass:
    """
    Given I store the number of machines in the :num_delete_workload clipboard
    Then the expression should be true> cb.num_delete_workload == cb.num_to_restore + 2
    """

