require 'spec_helper'

describe 'Pipeline', :feature, :js do
  include GitlabRoutingHelper

  let(:project) { create(:empty_project) }
  let(:user) { create(:user) }

  before do
    login_as(user)
    project.team << [user, :developer]
  end

  shared_context 'pipeline builds' do
    let!(:build_passed) do
      create(:ci_build, :success,
             pipeline: pipeline, stage: 'build', name: 'build')
    end

    let!(:build_failed) do
      create(:ci_build, :failed,
             pipeline: pipeline, stage: 'test', name: 'test', commands: 'test')
    end

    let!(:build_running) do
      create(:ci_build, :running,
             pipeline: pipeline, stage: 'deploy', name: 'deploy')
    end

    let!(:build_manual) do
      create(:ci_build, :manual,
             pipeline: pipeline, stage: 'deploy', name: 'manual-build')
    end

    let!(:build_external) do
      create(:generic_commit_status, status: 'success',
                                     pipeline: pipeline,
                                     name: 'jenkins',
                                     stage: 'external',
                                     target_url: 'http://gitlab.com/status')
    end
  end

  describe 'GET /:project/pipelines/:id' do
    include_context 'pipeline builds'

    let(:project) { create(:project) }
    let(:pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id) }

    before { visit namespace_project_pipeline_path(project.namespace, project, pipeline) }

    it 'shows the pipeline graph' do
      expect(page).to have_selector('.pipeline-visualization')
      expect(page).to have_content('Build')
      expect(page).to have_content('Test')
      expect(page).to have_content('Deploy')
      expect(page).to have_content('Retry')
      expect(page).to have_content('Cancel running')
    end

    it 'shows Pipeline tab pane as active' do
      expect(page).to have_css('#js-tab-pipeline.active')
    end

    describe 'pipeline graph' do
      context 'when pipeline has running builds' do
        it 'shows a running icon and a cancel action for the running build' do
          page.within('#ci-badge-deploy') do
            expect(page).to have_selector('.js-ci-status-icon-running')
            expect(page).to have_selector('.js-icon-action-cancel')
            expect(page).to have_content('deploy')
          end
        end

        it 'should be possible to cancel the running build' do
          find('#ci-badge-deploy .ci-action-icon-container').trigger('click')

          expect(page).not_to have_content('Cancel running')
        end
      end

      context 'when pipeline has successful builds' do
        it 'shows the success icon and a retry action for the successful build' do
          page.within('#ci-badge-build') do
            expect(page).to have_selector('.js-ci-status-icon-success')
            expect(page).to have_content('build')
          end

          page.within('#ci-badge-build .ci-action-icon-container') do
            expect(page).to have_selector('.js-icon-action-retry')
          end
        end

        it 'should be possible to retry the success job' do
          find('#ci-badge-build .ci-action-icon-container').trigger('click')

          expect(page).not_to have_content('Retry job')
        end
      end

      context 'when pipeline has failed builds' do
        it 'shows the failed icon and a retry action for the failed build' do
          page.within('#ci-badge-test') do
            expect(page).to have_selector('.js-ci-status-icon-failed')
            expect(page).to have_content('test')
          end

          page.within('#ci-badge-test .ci-action-icon-container') do
            expect(page).to have_selector('.js-icon-action-retry')
          end
        end

        it 'should be possible to retry the failed build' do
          find('#ci-badge-test .ci-action-icon-container').trigger('click')

          expect(page).not_to have_content('Retry job')
        end
      end

      context 'when pipeline has manual jobs' do
        it 'shows the skipped icon and a play action for the manual build' do
          page.within('#ci-badge-manual-build') do
            expect(page).to have_selector('.js-ci-status-icon-manual')
            expect(page).to have_content('manual')
          end

          page.within('#ci-badge-manual-build .ci-action-icon-container') do
            expect(page).to have_selector('.js-icon-action-play')
          end
        end

        it 'should be possible to play the manual job' do
          find('#ci-badge-manual-build .ci-action-icon-container').trigger('click')

          expect(page).not_to have_content('Play job')
        end
      end

      context 'when pipeline has external job' do
        it 'shows the success icon and the generic comit status build' do
          expect(page).to have_selector('.js-ci-status-icon-success')
          expect(page).to have_content('jenkins')
          expect(page).to have_link('jenkins', href: 'http://gitlab.com/status')
        end
      end
    end

    context 'page tabs' do
      it 'shows Pipeline and Jobs tabs with link' do
        expect(page).to have_link('Pipeline')
        expect(page).to have_link('Jobs')
      end

      it 'shows counter in Jobs tab' do
        expect(page.find('.js-builds-counter').text).to eq(pipeline.statuses.count.to_s)
      end

      it 'shows Pipeline tab as active' do
        expect(page).to have_css('.js-pipeline-tab-link.active')
      end
    end

    context 'retrying jobs' do
      it { expect(page).not_to have_content('retried') }

      context 'when retrying' do
        before { find('.js-retry-button').trigger('click') }

        it { expect(page).not_to have_content('Retry') }
      end
    end

    context 'canceling jobs' do
      it { expect(page).not_to have_selector('.ci-canceled') }

      context 'when canceling' do
        before { click_on 'Cancel running' }

        it { expect(page).not_to have_content('Cancel running') }
      end
    end
  end

  describe 'GET /:project/pipelines/:id/builds' do
    include_context 'pipeline builds'

    let(:project) { create(:project) }
    let(:pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id) }

    before do
      visit builds_namespace_project_pipeline_path(project.namespace, project, pipeline)
    end

    it 'shows a list of jobs' do
      expect(page).to have_content('Test')
      expect(page).to have_content(build_passed.id)
      expect(page).to have_content('Deploy')
      expect(page).to have_content(build_failed.id)
      expect(page).to have_content(build_running.id)
      expect(page).to have_content(build_external.id)
      expect(page).to have_content('Retry')
      expect(page).to have_content('Cancel running')
      expect(page).to have_link('Play')
    end

    it 'shows jobs tab pane as active' do
      expect(page).to have_css('#js-tab-builds.active')
    end

    context 'page tabs' do
      it 'shows Pipeline and Jobs tabs with link' do
        expect(page).to have_link('Pipeline')
        expect(page).to have_link('Jobs')
      end

      it 'shows counter in Jobs tab' do
        expect(page.find('.js-builds-counter').text).to eq(pipeline.statuses.count.to_s)
      end

      it 'shows Jobs tab as active' do
        expect(page).to have_css('li.js-builds-tab-link.active')
      end
    end

    context 'retrying jobs' do
      it { expect(page).not_to have_content('retried') }

      context 'when retrying' do
        before { find('.js-retry-button').trigger('click') }

        it { expect(page).not_to have_content('Retry') }
        it { expect(page).to have_selector('.retried') }
      end
    end

    context 'canceling jobs' do
      it { expect(page).not_to have_selector('.ci-canceled') }

      context 'when canceling' do
        before { click_on 'Cancel running' }

        it { expect(page).not_to have_content('Cancel running') }
        it { expect(page).to have_selector('.ci-canceled') }
      end
    end

    context 'playing manual job' do
      before do
        within '.pipeline-holder' do
          click_link('Play')
        end
      end

      it { expect(build_manual.reload).to be_pending }
    end
  end
end
