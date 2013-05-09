require 'celluloid'
require 'pry'

class Worker
  include Celluloid
  include Celluloid::Logger

  def initialize(number)
    @number = number
  end

  def run
    debug "#{@number}: sleeping"
    sleep rand(10) + 3
    debug "#{@number}: slept"
    "result from #{@number}"
  end
end

class Scatterer
  include Celluloid
  include Celluloid::Logger

  def initialize(workers)
    @workers = workers
  end

  def run(timeout: nil, lower_bound: @workers.size)
    debug "starting work: timeout=#{timeout.inspect} lower_bound=#{lower_bound.inspect}"

    futures = @workers.map do |worker|
      worker.future(:run)
    end

    gatherer = Gatherer.new(futures)
    gatherer.wait_for(timeout, lower_bound).tap do
      gatherer.terminate
    end
  end
end

class Gatherer
  include Celluloid
  include Celluloid::Logger

  Completion = Struct.new(:futures)
  class TimeoutError < StandardError
    def initialize(timeout, lower_bound, pending, ready)
      super("timeout reached: #{timeout.inspect}, lower bound: #{lower_bound.inspect}")
      @pending = pending
      @ready = ready
    end
    attr_reader :pending, :ready
  end

  def initialize(pending)
    @pending = pending
    @ready = []
  end

  def wait_for(timeout, lower_bound)
    condition = Condition.new

    @pending.each do |future|
      async.process(condition, future)
    end

    after(timeout) do
      debug "timeout reached!"

      if @ready.size >= lower_bound
        debug "reached lower bound"
        condition.signal Completion.new(@ready)
      else
        condition.signal TimeoutError.new(timeout, lower_bound, @pending.dup, @ready.dup)
      end
    end

    loop do
      result = condition.wait
      debug "condition returned: #{result.inspect}"
      case result
      when Future
        debug "future resolved: #{result.inspect}: #{result.value.inspect}"
        @ready << @pending.delete(result)
      when Exception
        raise result
      when Completion
        return result
      end

      if @pending.empty?
        debug "no pending futures left"
        return Completion.new(@ready)
      end
    end
  end

  def process(condition, future)
    debug "waiting for #{future.inspect}"
    future.value.tap do |value|
      debug "got result for #{future.inspect}: #{value.inspect}"
      condition.signal(future)
    end
  end
end

workers = 10.times.map do |i|
  Worker.new(i)
end
scatterer = Scatterer.new(workers)

Celluloid.logger.info "running"
begin
  result = scatterer.run(timeout: 6, lower_bound: 3)
  Celluloid.logger.info "results: #{result.futures.map(&:value).inspect}"
rescue Gatherer::TimeoutError => e
  Celluloid.logger.error "timed out: #{e.ready.map(&:value).inspect}"
  raise e
end

Celluloid.logger.info "finished"
