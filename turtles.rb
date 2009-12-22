#!/usr/bin/env ruby -w
#
# No warranty. And definitely no refunds.
#
# turtles.rb - Implement Object#andand in a turtles_all_the_way_down fashion.

# If you don't like this requirement, reimplement class_inheritable_accessor, et al. into your project
require 'active_support/core_ext'

module Turtles
  def self.included(base)
    base.class_eval do
      alias_method :method_missing_without_turtles, :method_missing
      alias_method :method_missing, :method_missing_with_turtles      

      # For a discussion of class_inheritable_accessor:
      # http://www.raulparolari.com/Rails/class_inheritable
      class_inheritable_accessor :turtles
      def self.turtles!;        self.turtles = true  ; end
      def self.no_turtles!;     self.turtles = false ; end
      def self.turtles?;     !! self.turtles         ; end
    end

    # Turtles are enabled by default upon inclusion
    base.turtles!
  end

  # For this thread of execution, the last chain of turtle calls, defined as
  # a chain that starts from an object, and goes through 0 or more instances
  # of NilClass. This is self-clearing by default - in other words, once
  # asked for, the caller is the only one with a reference to the array
  def last_chain( preserve=false )
    Thread.current[:turtle_chain] ||= []
    if preserve
      Thread.current[:turtle_chain]
    else
      old = Thread.current[:turtle_chain].dup
      Thread.current[:turtle_chain] = nil
      old
    end
  end
  module_function :last_chain
  
  # When we return nil through turtles, we add a singleton method on it to
  # mark it so we can build up a memory of the last call chain
  def method_missing_with_turtles(sym, *args, &block)
    if self.class.turtles?

      # initialize the stack when called on an object not returned by turtles
      unless self.respond_to?( '__made_by_turtles' )
        Turtles.last_chain(true).clear
      end
      Turtles.last_chain(true).push sym

      def nil.__made_by_turtles; true; end

      # returns the TurtleChain and reverts nil 
      def nil.turtle_chain
        c = Turtles.last_chain
        nil.metaclass.instance_eval do
          undef_method :__made_by_turtles if method_defined? :__made_by_turtles
          undef_method :turtle_chain if method_defined? :turtle_chain
        end
        c
      end
      nil
    else
      method_missing_without_turtles(sym, *args, &block)
    end
  end

end

# From here on out, the turtles? accessors are merged into Kernel/Object

class NilClass
  include Turtles
end

def turtles?
  NilClass.turtles?
end

def turtles!
  NilClass.turtles!
end

def no_turtles!
  NilClass.no_turtles!
end

# Also becomes a tool to narrow the scope for a turtle chain
def with_turtles
  Turtles.last_chain.clear
  already_turtles = turtles?
  turtles!
  begin
    result = yield
  ensure
    no_turtles! unless already_turtles
  end
  result
end

