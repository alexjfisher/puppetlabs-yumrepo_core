require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'

describe Puppet::Type.type(:yumrepo).provider(:inifile) do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  let(:yumrepo_dir) { tmpdir('yumrepo_integration_specs') }
  let(:yumrepo_file) { tmpfile('yumrepo_file', yumrepo_dir) }
  let(:yumrepo_conf_file) { tmpfile('yumrepo_conf_file', yumrepo_dir) }

  before :each do
    # We don't want to execute anything
    described_class.stubs(:filetype)
                   .returns Puppet::Util::FileType::FileTypeFlat

    # this mocks the reposdir logic in the provider and thus won't test for
    # issues like PUP-2916. Cover these types of issues in acceptance
    described_class.stubs(:reposdir).returns [yumrepo_dir]
    described_class.stubs(:repofiles).returns [yumrepo_conf_file]
  end

  after :each do
    # yumrepo provider class
    described_class.clear
  end

  describe 'when managing a yumrepo file it...' do
    let(:super_creative) { 'my.super.creati.ve' }
    let(:manifest) do
      "yumrepo { '#{super_creative}':
                    baseurl => 'http://#{super_creative}',
                    target  => '#{yumrepo_file}' }"
    end
    let(:expected_match) { "\[#{super_creative}\]\nbaseurl=http:\/\/my\.super\.creati\.ve" }

    it 'creates a new yumrepo file with mode 0644 and yumrepo entry' do
      apply_with_error_check(manifest)
      expect_file_mode(File.join(yumrepo_dir, super_creative + '.repo'), '644')
      expect(File.read(File.join(yumrepo_dir, super_creative + '.repo')))
        .to match(expected_match + "\n")
    end

    it 'removes a managed yumrepo entry' do
      apply_with_error_check(manifest)
      manifest = "yumrepo { '#{super_creative}':
                    ensure => absent,
                    target  => '#{yumrepo_file}' }"
      apply_with_error_check(manifest)
      expect(File.read(File.join(yumrepo_dir, super_creative + '.repo')))
        .to be_empty
    end

    it 'updates a managed yumrepo entry' do
      apply_with_error_check(manifest)
      manifest = "yumrepo { '#{super_creative}':
                    baseurl => 'http://#{super_creative}.updated',
                    target  => '#{yumrepo_file}' }"
      apply_with_error_check(manifest)
      expect(File.read(File.join(yumrepo_dir, super_creative + '.repo')))
        .to match(expected_match + ".updated\n")
    end

    it 'creates all properties of a yumrepo entry' do
      manifest = "yumrepo { '#{super_creative}':
                    baseurl => 'http://#{super_creative}',
                    target  => '#{yumrepo_file}' }"
      apply_with_error_check(manifest)
      expect(File.read(File.join(yumrepo_dir, super_creative + '.repo')))
        .to match("\[#{super_creative}\]")
    end

    # The unit-tests cover all properties
    #   and we have to hard-code the "should" values here.
    # Puppet::Type.type(:yumrepo).validproperties contains the full list
    #   but we can't get the property "should" values from the yumrepo-type
    #   without having an instance of type, which is what yumrepo defines...
    #   Just cover the most probable used properties.
    properties = { 'bandwidth' => '42M',
                   'baseurl'        => 'http://er0ck',
                   'cost'           => '42',
                   'enabled'        => 'yes',
                   'exclude'        => 'er0ckSet2.0',
                   'failovermethod' => 'roundrobin',
                   'include'        => 'https://er0ck',
                   'mirrorlist'     => 'https://er0ckMirr0r.co',
                   'priority'       => '99',
                   'retries'        => '413189',
                   'timeout'        => '666' }

    it 'creates an entry with various properties' do
      manifest = "yumrepo { '#{super_creative}':
                          target  => '#{yumrepo_file}',\n"
      properties.each do |property_key, property_value|
        manifest << "#{property_key} => '#{property_value}',\n"
      end
      manifest << '}'
      apply_with_error_check(manifest)
      file_lines = File.read(File.join(yumrepo_dir, super_creative + '.repo'))
      properties.each do |property_key, property_value|
        if property_value =~ %r{^(true|false|no|yes)$}
          property_value = property_value.capitalize
        end
        expect(file_lines).to match(%r{^#{property_key}=#{Regexp.escape(property_value)}$})
      end
    end

    # #puppet resource yumrepo
    it 'fetches the yumrepo entries from resource face' do
      resource_app = Puppet::Application[:resource]
      resource_app.preinit
      resource_app
        .command_line.stubs(:args)
        .returns(['yumrepo', super_creative])

      resource_app.expects(:puts).with do |args|
        expect(args).to match(%r{#{super_creative}})
      end
      resource_app.main
    end
  end
end
