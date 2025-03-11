# Helm Chart Tests

This directory contains tests for the Helm charts in this repository. The tests are organized into different categories:

- **Unit Tests**: Test individual templates within a chart
- **Integration Tests**: Test the chart as a whole
- **End-to-End Tests**: Test the chart in a real environment

## Directory Structure

```
tests/
├── unit/               # Unit tests
│   ├── output/         # Output directory for unit tests
│   └── *.sh            # Unit test scripts
├── integration/        # Integration tests
│   ├── output/         # Output directory for integration tests
│   └── *.sh            # Integration test scripts
└── e2e/                # End-to-end tests (not implemented yet)
```

## Running Tests

### Unit Tests

Unit tests validate individual templates within a chart. They render templates with specific values and check that the output matches the expected result.

To run all unit tests:

```bash
for test in tests/unit/*.sh; do
  if [ -x "$test" ]; then
    echo "Running unit test: $test"
    $test
  fi
done
```

To run a specific unit test:

```bash
./tests/unit/test-namespace-aware.sh
```

### Integration Tests

Integration tests validate the chart as a whole. They install the chart in a test environment and check that the resources are created correctly.

To run all integration tests:

```bash
for test in tests/integration/*.sh; do
  if [ -x "$test" ]; then
    echo "Running integration test: $test"
    $test
  fi
done
```

To run a specific integration test:

```bash
./tests/integration/test-multi-namespace.sh
```

### End-to-End Tests

End-to-end tests validate the chart in a real environment. They deploy the chart to a Kubernetes cluster and check that the deployed application works as expected.

*Note: End-to-end tests are not implemented yet.*

## Test Scripts

### Unit Tests

- **test-namespace-aware.sh**: Tests that the chart produces namespace-aware resource names and supports custom annotations

### Integration Tests

- **test-multi-namespace.sh**: Tests that the chart can be deployed in multiple namespaces with complete isolation

## Automated Testing

The tests are automatically run on every push to the main branch and on every pull request. The results are available in the GitHub Actions tab.

To run the tests locally, you can use the test-charts.sh script:

```bash
./test-charts.sh --chart ingress --values test-values.yaml
```

This will:
1. Lint the chart
2. Render the templates
3. Skip the dry-run installation (due to CRD ownership issues)

## Adding New Tests

To add a new test:

1. Create a new script in the appropriate directory (unit, integration, or e2e)
2. Make the script executable: `chmod +x tests/unit/your-test.sh`
3. Add the test to the GitHub Actions workflow in `.github/workflows/test-charts.yml`

## Test-Driven Development (TDD)

The tests in this repository follow the Test-Driven Development (TDD) approach:

1. Write a failing test
2. Implement the feature to make the test pass
3. Refactor the code while ensuring the test still passes

For more information on TDD for Helm charts, see the [helm-chart-tdd.md](../helm-chart-tdd.md) file.
