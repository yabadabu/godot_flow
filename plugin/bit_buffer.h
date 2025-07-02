#pragma once

#include <godot_cpp/variant/packed_byte_array.hpp>

namespace godot {

// Helper class
class BitBuffer {
private:
  PackedByteArray data;
    
public:
  void set_bit(int bit_index, bool value) {
    int byte_index = bit_index / 8;
    int bit_offset = bit_index % 8;
    
    if (byte_index >= data.size())
      data.resize(byte_index + 1);
    
    if (value)
      data[byte_index] |= (1 << bit_offset);
    else
      data[byte_index] &= ~(1 << bit_offset);
  }
  
  bool get_bit(int bit_index) const {
    int byte_index = bit_index / 8;
    int bit_offset = bit_index % 8;
    
    if (byte_index >= data.size()) 
      return false;
    
    return (data[byte_index] & (1 << bit_offset)) != 0;
  }
  
  PackedByteArray& get_data() { return data; }
};

}