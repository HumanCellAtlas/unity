# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
@reference_analysis = ReferenceAnalysis.create(firecloud_project: 'unity-benchmarking-development',
                                               firecloud_workspace: 'test-workspace',
                                               analysis_wdl: 'unity-benchmark-development/test-analysis/5',
                                               benchmark_wdl: 'unity-benchmark-development/test-benchmark/3',
                                               orchestration_wdl: 'unity-benchmark-development/test-orchestration/2')
@reference_analysis.load_parameters_from_wdl!
@user = User.create(provider: 'google_oauth2', uid: 123545, email: 'unity-admin@broadinstitute.org',
                    registered_for_firecloud: true, admin: true)