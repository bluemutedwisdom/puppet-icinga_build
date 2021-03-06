require 'spec_helper'

describe 'icinga_build::pipeline::deb' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let :facts do
        facts
      end

      context 'with a simple example' do
        let :title do
          'icinga2-snapshot-debian-jessie'
        end

        let :pre_condition do
          "class { 'icinga_build::pipeline::defaults':
            arch           => ['x86_64', 'x86'],
            jenkins_label  => 'docker-test',
            docker_image   => 'private-registry:5000/icinga/{os}-{dist}-{arch}',
            aptly_server   => 'http://localhost',
            aptly_user     => 'admin',
            aptly_password => 'admin',
          }"
        end

        let :params do
          {
            product:         'icinga2',
            pipeline:        'icinga2-snapshot',
            control_repo:    'https://github.com/Icinga/icinga-packaging.git',
            control_branch:  'snapshot',
            upstream_repo:   'https://github.com/Icinga/icinga2.git',
            upstream_branch: 'support/x.x',
            release_type:    'snapshot'
          }
        end

        it { should compile.with_all_deps }

        it { should contain_class('icinga_build::pipeline::defaults') }

        # pre_condition
        it { should contain_icinga_build__pipeline__deb('icinga2-snapshot-debian-jessie') }

        it do
          should contain_jenkins_job('icinga2-snapshot/deb-debian-jessie-0source')
            .with_config(/#{Regexp.escape(params[:control_repo])}/)
            .with_config(%r{BranchSpec.*\r?\n.*origin/support/x.x})
            .with_config(%r{<assignedNode>docker-test</assignedNode>})
            .with_config(%r{<image>private-registry:5000/icinga/debian-jessie-x86_64</image>})
            .with_config(%r{<projectNameList>\s*<string>deb-debian-jessie-1binary</string>\s*</projectNameList>}m)
            .with_config(/project="icinga2"/)
            .with_config(/os="debian"/)
            .with_config(/dist="jessie"/)
            .with_config(/use_dist="jessie"/)
            .with_config(%r{upstream_branch="support/x.x"})
            .with_config(/dpkg-buildpackage/)
        end

        it do
          should contain_jenkins_job('icinga2-snapshot/deb-debian-jessie-1binary')
            .with_config(/matrix-project/)
            .with_config(%r{<assignedNode>docker-test</assignedNode>})
            .with_config(%r{<image>private-registry:5000/icinga/debian-jessie-\$arch</image>})
            .with_config(%r{<projectNameList>\s*<string>deb-debian-jessie-2test</string>\s*</projectNameList>}m)
            .with_config(%r{<upstreamProjects>deb-debian-jessie-0source</upstreamProjects>})
            .with_config(%r{<hudson.matrix.TextAxis>\s*<name>arch</name>\s*<values>\s*<string>x86_64</string>\s*<string>x86</string>\s*</values>\s*</hudson.matrix.TextAxis>}m)
            .with_config(%r{<project>icinga2-snapshot/deb-debian-jessie-0source</project>}) # copy artifacts from
            .with_config(/project="icinga2"/)
            .with_config(/os="debian"/)
            .with_config(/dist="jessie"/)
            .without_config(/^arch=/)
            .with_config(/dpkg-buildpackage/)
        end

        it 'should have a test job' do
          should contain_jenkins_job('icinga2-snapshot/deb-debian-jessie-2test')
            .with_config(/matrix-project/)
            .with_config(/project="icinga2"/)
            .with_config(%r{/start_test.sh})
        end

        it 'should have a publish job' do

          should contain_jenkins_job('icinga2-snapshot/deb-debian-jessie-3publish').with_ensure(:absent)

          should contain_jenkins_job('icinga2-snapshot/deb-debian-jessie-3-publish')
            .with_config(/<project>/)
            .with_config(/project="icinga2"/)
            .with_config(/os="debian"/)
            .with_config(/dist="jessie"/)
            .with_config(/publish_type="deb"/)
            .without_config(/^arch=/)
            .with_config(/curl_aptly/)
        end
      end
    end
  end
end
