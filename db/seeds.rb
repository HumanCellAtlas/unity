# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
AdminConfiguration.create(config_type: 'Unity FireCloud User Group', value_type: 'string', value: 'unity-benchmark-users')
@reference_analysis = ReferenceAnalysis.create(firecloud_project: 'unity-benchmark-test',
                                               firecloud_workspace: 'test-workspace',
                                               analysis_wdl: 'unity-benchmark-test/test-analysis/1',
                                               benchmark_wdl: 'unity-benchmark-test/test-benchmark/1',
                                               orchestration_wdl: 'unity-benchmark-test/test-orchestration/1')
@reference_analysis.load_parameters_from_wdl!
@user = User.create(provider: 'google_oauth2', uid: 123545, email: 'unity-admin@broadinstitute.org',
                    registered_for_firecloud: true, admin: true)
@user2 = User.create(provider: 'google_oauth2', uid: 132515, email: 'unity-curator@broadinstitute.org',
                    registered_for_firecloud: true, curator: true)