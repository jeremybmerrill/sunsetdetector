# encoding: utf-8

#raw_data = [0.004299001, 0.004811451, 0.004561731, 0.016644016, 0.008045992, 0.003356497, 0.003370698, 0.01310685, 0.002636054, 0.002385233, 0.011085073, 0.011993262, 0.008939891, 0.012997719, 0.015034985, 0.008369158, 0.008535785, 0.009698186, 0.019391219, 0.021957221, 0.003241812, 0.003790354, 0.003916101, 0.0264235, 0.022141973, 0.030508232, 0.03863787, 0.011466802, 0.01283518, 0.015104303, 0.024212809, 0.027597734, 0.029966942, 0.032189853, 0.03118853, 0.032784405, 0.027369773, 0.044014926, 0.042189684, 0.023305289, 0.042260402, 0.041699634, 0.019598732, 0.02468654, 0.026260053, 0.032082352, 0.047220366, 0.048731417, 0.06472207, 0.044909806, 0.060666047, 0.068535367, 0.079476707, 0.068964197, 0.079709406, 0.079725851, 0.0583639, 0.030141935, 0.039077007, 0.039040691, 0.033428311, 0.021521109, 0.026369774, 0.018634062, 0.030512841, 0.003730226, 0.012204444, 0.004130489, 0, 0, 0, 0, 0.00227186, 0.004786254, 0.002882635, 0.003982814, 0.003567368, 0.008210306, 0.01325945, 0.006388206, 0.028441726, 0.01029479, 0.009781159, 0.01907222, 0.024708187, 0.002975407, 0.017901638, 0.009567669, 0.003881107, 0.009709248, 0.006054228, 0.005115006, 0.004878283, 0.004700814, 0.004953891, 0.004137053, 0.004869517, 0.004371238, 0.004096575, 0.004222398, 0.003867985, 0.003361959, 0.004068132, 0.005234506, 0.004854178, 0.004947316, 0.00681809, 0.002339445]

# new_length = 2 ** Math.log(raw_data.length, 2).ceil
# padding_needed = new_length - raw_data.length
# raw_data += [0] * padding_needed
# data = GSL::Vector.alloc(raw_data)
# coefficients = data.fft

# thing = []

# coefficients = coefficients.to_a.map{|coefficient| coefficient > 0.2 ? coefficient : 0 }

# coefficients.to_a.each_with_index do |coefficient, index|
#   thing << "#{coefficient}*cos(#{(index* 2)-1}*πx/2)" unless coefficient == 0
# end

# puts "y=" + thing.join("+")
# 1.93*cos(πx/2)+-0.73*cos(3πx/2)

require 'gsl'

module FancyPantsMath
  def FancyPantsMath.do_some_calculus(truncated_data)
    return false if truncated_data.size < 5

    coeff = GSL::Vector.alloc(truncated_data).fft.to_a
    dc_value = coeff.first #y-intercept, whatever.
    coeff_rest = coeff[1..-1]

    largest_coeff = coeff_rest.max

    index_of_largest_coeff = coeff_rest.index(largest_coeff) + 1 # +1 because we want its index with the dc_value as index 0.

    period = coeff.size

    c = largest_coeff
    k = index_of_largest_coeff

    #showing my work!
    #prettier functions
    sunsettiness_time = "#{dc_value}+#{c}*cos( (#{k}*2π*x) / #{period})"
    puts sunsettiness_time
    first_derivative_sunsettiness_wrt_time = "-#{c}*(#{k}*2π/#{period})*sin(#{k}*2π*x) / #{period})"
    second_derivative_sunsettiness_wrt_time = "-#{c}*(#{k}*2π/#{period})^2*cos(#{k}*2π*x) / #{period})"
    #actual functions
    sunsettiness = lambda{|x| dc_value + largest_coeff * Math.cos( k * 2 * Math::PI * x / period )}
    first_derivative = lambda{|x| -1 * c * k * 2 * Math::PI / period * Math.sin(k * 2 * Math::PI * x / period)}
    second_derivative = lambda{|x|  -1 * c * ((k * 2 * Math::PI / period) ** 2) * Math.cos(k * 2 * Math::PI * x)}

    #the "x" value here is just the location on the timeline; at a frequency of one photo / minute (ish)
    return second_derivative.call(truncated_data.size() -1) < 0 && second_derivative.call(truncated_data.size() -1) > 0
    ##### CALCULUS 101 ########
    #in general.
    #so given f(x) = cos(2x)
    # df/dx = -2sin(2x)
    # then ddf/dx/dx = d/dx d/dx cos(x) = -4cos(2x)
    #but various constants and things having been flattened, f is changing most rapidly when f'' = 0.



    #e.g. truncated_coeff = => [1.751297768, 0, 0.9489264930533873, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    #somehow, transform this into a (differentiable) function.
    #differentiate that function and, based on the value as of the most recent sunset (e.g. if slope ought to be at its highest.), tweet or not.
  end
end