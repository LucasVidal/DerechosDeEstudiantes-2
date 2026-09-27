require 'test_helper'
require 'tmpdir'

class CkanReportPublisherTest < ActiveSupport::TestCase
  def setup_fixtures
  end

  def teardown_fixtures
  end

  class FakeClient
    attr_reader :created_resources, :updated_resources

    def initialize(package: nil)
      @package = package
      @created_resources = []
      @updated_resources = []
    end

    def package_show(id:)
      @package
    end

    def package_create(attributes)
      @package = attributes.stringify_keys.merge('id' => 'package-id', 'resources' => [])
    end

    def resource_create(attributes, upload: nil)
      resource = attributes.stringify_keys.merge('id' => "resource-#{@created_resources.length + 1}")
      @created_resources << resource
      @package['resources'] << resource
      resource
    end

    def resource_update(attributes, upload: nil)
      @updated_resources << attributes
      attributes
    end
  end

  test 'creates four named resources and updates them on the next run' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'preguntas.json')
      File.write(path, '[]')
      exported_files = {
        'preguntas' => { json: path },
        'respuestas' => { json: path },
        'dudas' => { json: path },
        'derechos' => { json: path }
      }
      client = FakeClient.new
      publisher = CkanReportPublisher.new(
        client: client,
        credentials: { organization: 'datauy' },
        public_base_url: 'https://derechosdeestudiantes.edu.uy'
      )

      publisher.publish(exported_files: exported_files)
      publisher.publish(exported_files: exported_files)

      assert_equal %w[preguntas respuestas dudas derechos], client.created_resources.map { |resource| resource['name'] }
      assert_equal 4, client.updated_resources.length
      assert_equal %w[preguntas respuestas dudas derechos], client.updated_resources.map { |resource| resource[:name] }
      assert_equal 'https://derechosdeestudiantes.edu.uy/data/latest/preguntas.json', client.updated_resources.first[:url]
    end
  end

  test 'requires an organization' do
    assert_raises(ArgumentError) do
      CkanReportPublisher.new(client: FakeClient.new, credentials: {})
    end
  end
end
