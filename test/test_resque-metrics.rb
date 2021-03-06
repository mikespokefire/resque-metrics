require 'helper'

class TestResqueMetrics < MiniTest::Unit::TestCase
  def setup
    Resque.redis.flushall

    Resque.before_first_fork = nil
    Resque.before_fork = nil
    Resque.after_fork = nil

    @num_jobs = 4
    @worker = Resque::Worker.new(:jobs)
    @num_jobs.times do
      work_job
    end
  end

  def test_should_pass_resque_plugin_lint
    assert Resque::Plugin.lint(Resque::Metrics::Hooks)
  end

  def test_should_perform_job
    assert Resque::Job.new(:jobs, 'class' => SomeJob, 'args' => [1,2]).perform
  end

  def test_should_record_total_job_time
    assert Resque::Metrics.total_job_time > 0
    assert Resque::Metrics.total_job_time_by_queue(:jobs) > 0
    assert Resque::Metrics.total_job_time_by_job(SomeJob) > 0
  end

  def test_should_record_enqueue_count
    assert_equal @num_jobs, Resque::Metrics.total_enqueue_count
    assert_equal @num_jobs, Resque::Metrics.total_enqueue_count_by_queue(:jobs)
    assert_equal @num_jobs, Resque::Metrics.total_enqueue_count_by_job(SomeJob)
  end

  def test_should_record_job_count
    assert Resque::Metrics.total_job_count > 0
    assert Resque::Metrics.total_job_count_by_queue(:jobs) > 0
    assert Resque::Metrics.total_job_count_by_job(SomeJob) > 0
  end

  def test_should_record_payload_size
    assert Resque::Metrics.total_payload_size > 0
    assert Resque::Metrics.total_payload_size_by_queue(:jobs) > 0
    assert Resque::Metrics.total_payload_size_by_job(SomeJob) > 0
  end

  def test_should_record_avg_job_time
    assert Resque::Metrics.avg_job_time > 0
    assert Resque::Metrics.avg_job_time_by_queue(:jobs) > 0
    assert Resque::Metrics.avg_job_time_by_job(SomeJob) > 0
  end

  def test_should_call_callbacks
    recorded = []
    recorded_count = 0
    Resque::Metrics.on_job_complete do |klass, queue, time|
      recorded << [klass, queue, time]
    end
    Resque::Metrics.on_job_complete do |klass, queue, time|
      recorded_count += 1
    end
    work_job
    work_job
    assert_equal 2, recorded.length
    assert_equal SomeJob, recorded[0][0]
    assert_equal :jobs, recorded[0][1]
    assert recorded[0][2] > 0
    assert_equal 2, recorded_count
  end

  def test_should_record_fork_times
    Resque::Metrics.watch_fork
    Resque.after_fork do |job|
      sleep 0.1
      Resque::Metrics.after_fork.call(job)
    end
    work_job
    work_job
    assert_equal 2, Resque::Metrics.total_fork_count
    assert Resque::Metrics.avg_fork_time > 0
    assert Resque::Metrics.avg_fork_time_by_queue(:jobs) > 0
    assert Resque::Metrics.avg_fork_time_by_job(SomeJob) > 0
  end

  private
  def work_job
    Resque.enqueue(SomeJob, 20, '/tmp')
    @worker.work(0)
  end

end
