package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/cloudposse/test-helpers/pkg/atmos"
	helper "github.com/cloudposse/test-helpers/pkg/atmos/component-helper"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/stretchr/testify/assert"
)

type ComponentSuite struct {
	helper.TestSuite
}

func (s *ComponentSuite) TestBasic() {
	const component = "codeartifact/basic"
	const stack = "default-test"
	const awsRegion = "us-east-2"

	// Domain names are unique per account and Region, and the suite runs once for
	// Terraform and once for OpenTofu, so every run gets its own domain.
	domainName := fmt.Sprintf("eg-test-%s", strings.ToLower(random.UniqueId()))
	inputs := map[string]interface{}{
		"domain_name": domainName,
	}

	defer s.DestroyAtmosComponent(s.T(), component, stack, &inputs)
	options, _ := s.DeployAtmosComponent(s.T(), component, stack, &inputs)
	assert.NotNil(s.T(), options)

	awsAccountId := aws.GetAccountId(s.T())

	assert.Equal(s.T(), domainName, atmos.Output(s.T(), options, "domain_name"))
	assert.Equal(s.T(), awsAccountId, atmos.Output(s.T(), options, "domain_owner"))
	assert.Equal(s.T(), fmt.Sprintf("arn:aws:codeartifact:%s:%s:domain/%s", awsRegion, awsAccountId, domainName), atmos.Output(s.T(), options, "domain_arn"))

	repositoryArns := atmos.OutputMap(s.T(), options, "repository_arns")
	assert.Equal(s.T(), fmt.Sprintf("arn:aws:codeartifact:%s:%s:repository/%s/python", awsRegion, awsAccountId, domainName), repositoryArns["python"])
	assert.Equal(s.T(), fmt.Sprintf("arn:aws:codeartifact:%s:%s:repository/%s/pypi-store", awsRegion, awsAccountId, domainName), repositoryArns["pypi-store"])

	var endpoints map[string]map[string]string
	atmos.OutputStruct(s.T(), options, "repository_endpoints", &endpoints)
	assert.Equal(s.T(), fmt.Sprintf("https://%s-%s.d.codeartifact.%s.amazonaws.com/pypi/python/", domainName, awsAccountId, awsRegion), endpoints["python"]["pypi"])

	packageGroupArns := atmos.OutputMap(s.T(), options, "package_group_arns")
	assert.Len(s.T(), packageGroupArns, 1)
	assert.Contains(s.T(), packageGroupArns, "first-party")

	s.DriftTest(component, stack, &inputs)
}

func (s *ComponentSuite) TestEnabledFlag() {
	const component = "codeartifact/disabled"
	const stack = "default-test"
	s.VerifyEnabledFlag(component, stack, nil)
}

func TestRunSuite(t *testing.T) {
	suite := new(ComponentSuite)
	helper.Run(t, suite)
}
