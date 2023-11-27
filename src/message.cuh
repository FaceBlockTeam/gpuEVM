#ifndef _MESSAGE_H_
#define _MESSAGE_H_

#include "utils.h"

template<class params>
class message_t {
  public:
    typedef arith_env_t<params>                     arith_t;
    typedef typename arith_t::bn_t                  bn_t;
    typedef cgbn_mem_t<params::BITS>                evm_word_t;
  
    typedef struct {
      evm_word_t origin;
      evm_word_t gasprice;
    } tx_t;

    typedef struct  {
      evm_word_t      caller;
      evm_word_t      value;
      evm_word_t      to;
      evm_word_t      nonce;
      tx_t            tx;
      evm_word_t      gas;
      uint32_t        depth;
      uint32_t        call_type; // OP_CALL - call, OP_CALLCODE - callcode, OP_STATICCALL - static call, OP_DELEGATECALL - delegate call, OP_CREATE - create, OP_CREATE2 - create2
      evm_word_t      storage;
      data_content_t  data;
    } message_content_t;

    message_content_t *_content;
    arith_t           _arith;

    __host__ __device__ message_t(arith_t arith, message_content_t *content) : _arith(arith), _content(content) {
    }

    __host__ message_t(arith_t arith, const cJSON *test) : _arith(arith) {
        size_t count;
        _content = (message_content_t *)malloc(sizeof(message_content_t));
        message_content_t *cpu_messages = get_messages(test, count);
        memcpy(_content, &(cpu_messages[0]), sizeof(message_content_t));
        if (_content->data.size > 0) {
          _content->data.data = (uint8_t *)malloc(sizeof(uint8_t)*_content->data.size);
          memcpy(_content->data.data, cpu_messages[0].data.data, sizeof(uint8_t)*_content->data.size);
        } else {
          _content->data.data = NULL;
        }
        free_messages(cpu_messages, count);
    }

    __host__ __device__ void free_memory() {
      ONE_THREAD_PER_INSTANCE(
        if (_content->data.size > 0) {
          free(_content->data.data);
        }
        free(_content);
      )
    }

    __host__ __device__ __forceinline__ void get_caller(bn_t &caller) {
      cgbn_load(_arith._env, caller, &(_content->caller));
    }

    __host__ __device__ __forceinline__ void get_value(bn_t &value) {
      cgbn_load(_arith._env, value, &(_content->value));
    }

    __host__ __device__ __forceinline__ void get_to(bn_t &to) {
      cgbn_load(_arith._env, to, &(_content->to));
    }

    __host__ __device__ __forceinline__ void get_nonce(bn_t &nonce) {
      cgbn_load(_arith._env, nonce, &(_content->nonce));
    }

    __host__ __device__ __forceinline__ void get_tx_origin(bn_t &tx_origin) {
      cgbn_load(_arith._env, tx_origin, &(_content->tx.origin));
    }

    __host__ __device__ __forceinline__ void get_tx_gasprice(bn_t &tx_gasprice) {
      cgbn_load(_arith._env, tx_gasprice, &(_content->tx.gasprice));
    }

    __host__ __device__ __forceinline__ void get_gas(bn_t &gas) {
      cgbn_load(_arith._env, gas, &(_content->gas));
    }

    __host__ __device__ __forceinline__ uint32_t get_depth() {
      return _content->depth;
    }

    __host__ __device__ __forceinline__ uint32_t get_call_type() {
      return _content->call_type;
    }

    __host__ __device__ __forceinline__ void get_storage(bn_t &storage) {
      cgbn_load(_arith._env, storage, &(_content->storage));
    }

    __host__ __device__ __forceinline__ size_t get_data_size() {
      return _content->data.size;
    }

    __host__ __device__ __forceinline__ uint8_t *get_data(size_t index, size_t length, size_t &available_size) {
      available_size = length;
      size_t last_offset = index + length;
      // verify for overflow
      // TODO: verify also in evm in opcode if the value is larger than size_t
      if ( (last_offset < index) || (last_offset < length)) {
        if (index < _content->data.size) {
          available_size = _content->data.size - index;
          return _content->data.data + index;
        } else {
          available_size = 0;
          return _content->data.data;
        }
      } else if (index >= _content->data.size) {
        available_size = 0;
        return _content->data.data;
      } else if (index + length <= _content->data.size) {
        return _content->data.data + index;
      } else if (index < _content->data.size) {
        available_size = _content->data.size - index;
        return _content->data.data + index;
      } else {
        available_size = 0;
        return _content->data.data;
      }
    }

    __host__ message_content_t *to_gpu() {
      message_content_t *gpu_content, *tmp_cpu_content;
      tmp_cpu_content = (message_content_t *)malloc(sizeof(message_content_t));
      memcpy(tmp_cpu_content, _content, sizeof(message_content_t));
      if (tmp_cpu_content->data.size > 0) {
        cudaMalloc((void **)&(tmp_cpu_content->data.data), sizeof(uint8_t)*tmp_cpu_content->data.size);
        cudaMemcpy(tmp_cpu_content->data.data, _content->data.data, sizeof(uint8_t)*tmp_cpu_content->data.size, cudaMemcpyHostToDevice);
      } else {
        tmp_cpu_content->data.data = NULL;
      }
      cudaMalloc((void **)&gpu_content, sizeof(message_content_t));
      cudaMemcpy(gpu_content, tmp_cpu_content, sizeof(message_content_t), cudaMemcpyHostToDevice);
      free(tmp_cpu_content);
      return gpu_content;
    }

    __host__ void free_gpu() {
      message_content_t *tmp_cpu_content;
      tmp_cpu_content = (message_content_t *)malloc(sizeof(message_content_t));
      cudaMemcpy(tmp_cpu_content, _content, sizeof(message_content_t), cudaMemcpyDeviceToHost);
      if (tmp_cpu_content->data.size > 0) {
        cudaFree(tmp_cpu_content->data.data);
      }
      free(tmp_cpu_content);
      cudaFree(_content);
    }

    __host__ __device__ void print() {
      printf("CALLER: ");
      print_bn<params>(_content->caller);
      printf(", VALUE: ");
      print_bn<params>(_content->value);
      printf(", TO: ");
      print_bn<params>(_content->to);
      printf(", NONCE: ");
      print_bn<params>(_content->nonce);
      printf(", TX_ORIGIN: ");
      print_bn<params>(_content->tx.origin);
      printf(", TX_GASPRICE: ");
      print_bn<params>(_content->tx.gasprice);
      printf(", DEPTH: %d", _content->depth);
      printf(", CALL_TYPE: %d", _content->call_type);
      printf(", DATA_SIZE: ");
      printf("%lx ", _content->data.size);
      printf("\n");
      if (_content->data.size > 0) {
        printf("DATA: ");
        print_bytes(_content->data.data, _content->data.size);
        printf("\n");
      }
    }

    __host__ cJSON *to_json() {
      cJSON *transaction_json = cJSON_CreateObject();
      char *hex_string_ptr=(char *) malloc(sizeof(char) * ((params::BITS/32)*8+3));
      char *bytes_string=NULL;
      
      // set the caller
      _arith.from_cgbn_memory_to_hex(_content->caller, hex_string_ptr, 5); //address
      cJSON_AddStringToObject(transaction_json, "sender", hex_string_ptr);
      
      // set the value
      _arith.from_cgbn_memory_to_hex(_content->value, hex_string_ptr);
      cJSON_AddStringToObject(transaction_json, "value", hex_string_ptr);

      // set the to
      _arith.from_cgbn_memory_to_hex(_content->to, hex_string_ptr, 5); //address
      cJSON_AddStringToObject(transaction_json, "to", hex_string_ptr);

      // set the nonce
      _arith.from_cgbn_memory_to_hex(_content->nonce, hex_string_ptr);
      cJSON_AddStringToObject(transaction_json, "nonce", hex_string_ptr);

      // set the tx.origin
      _arith.from_cgbn_memory_to_hex(_content->tx.origin, hex_string_ptr, 5); //address
      cJSON_AddStringToObject(transaction_json, "origin", hex_string_ptr);

      // set the tx.gasprice
      _arith.from_cgbn_memory_to_hex(_content->tx.gasprice, hex_string_ptr);
      cJSON_AddStringToObject(transaction_json, "gasPrice", hex_string_ptr);

      // set the gas
      _arith.from_cgbn_memory_to_hex(_content->gas, hex_string_ptr);
      cJSON_AddStringToObject(transaction_json, "gasLimit", hex_string_ptr);

      // set the data
      if (_content->data.size > 0) {
        bytes_string = bytes_to_hex(_content->data.data, _content->data.size);
        cJSON_AddStringToObject(transaction_json, "data", bytes_string);
        free(bytes_string);
      } else {
        cJSON_AddStringToObject(transaction_json, "data", "0x");
      }

      free(hex_string_ptr);
      return transaction_json;
    }

    __host__ static message_content_t *get_messages(const cJSON *test, size_t &count) {
      const cJSON *messages_json = cJSON_GetObjectItemCaseSensitive(test, "transaction");
      message_content_t *cpu_messages = NULL;
      mpz_t caller, value, nonce, to, tx_origin, tx_gasprice, gas;
      char *hex_string=NULL;
      mpz_init(caller);
      mpz_init(value);
      mpz_init(to);
      mpz_init(nonce);
      mpz_init(tx_origin);
      mpz_init(tx_gasprice);
      mpz_init(gas);
      const cJSON *data_json = cJSON_GetObjectItemCaseSensitive(messages_json, "data");
      size_t data_counts = cJSON_GetArraySize(data_json);

      const cJSON *gas_limit_json = cJSON_GetObjectItemCaseSensitive(messages_json, "gasLimit");
      size_t gas_limit_counts = cJSON_GetArraySize(gas_limit_json);

      const cJSON *gas_price_json = cJSON_GetObjectItemCaseSensitive(messages_json, "gasPrice");
      hex_string = gas_price_json->valuestring;
      adjusted_length(&hex_string);
      mpz_set_str(tx_gasprice, hex_string, 16);

      const cJSON *nonce_json = cJSON_GetObjectItemCaseSensitive(messages_json, "nonce");
      hex_string = nonce_json->valuestring;
      adjusted_length(&hex_string);
      mpz_set_str(nonce, hex_string, 16);

      const cJSON *to_json = cJSON_GetObjectItemCaseSensitive(messages_json, "to");
      uint32_t call_type = OP_CALL;
      hex_string = to_json->valuestring;
      if (strlen(hex_string) == 0) {
        mpz_set_ui(to, 0);
        call_type=OP_CREATE; //to see if it is not create2
      } else {
        adjusted_length(&hex_string);
        mpz_set_str(to, hex_string, 16);
      }


      const cJSON *value_json = cJSON_GetObjectItemCaseSensitive(messages_json, "value");
      size_t value_counts = cJSON_GetArraySize(value_json);

      const cJSON *caller_json = cJSON_GetObjectItemCaseSensitive(messages_json, "sender");
      hex_string = caller_json->valuestring;
      adjusted_length(&hex_string);
      mpz_set_str(caller, hex_string, 16);
      mpz_set_str(tx_origin, hex_string, 16);

      count = data_counts * gas_limit_counts * value_counts;
      cpu_messages = (message_content_t *)malloc(sizeof(message_content_t)*count);
      size_t idx=0, jdx=0, kdx=0, instance_idx=0;
      size_t data_size;
      uint8_t *data_content;

      for(idx=0; idx<data_counts; idx++) {
        hex_string = cJSON_GetArrayItem(data_json, idx)->valuestring;
        data_size = adjusted_length(&hex_string);
        if (data_size > 0) {
          data_content = (uint8_t *) malloc (data_size);
          hex_to_bytes(hex_string, data_content, 2 * data_size);
        } else {
          data_content = NULL;
        }

        for(jdx=0; jdx<gas_limit_counts; jdx++) {
          hex_string = cJSON_GetArrayItem(gas_limit_json, jdx)->valuestring;
          adjusted_length(&hex_string);
          mpz_set_str(gas, hex_string, 16);

          for(kdx=0; kdx<value_counts; kdx++) {
            hex_string = cJSON_GetArrayItem(value_json, kdx)->valuestring;
            adjusted_length(&hex_string);
            mpz_set_str(value, hex_string, 16);

            cpu_messages[instance_idx].data.size = data_size;
            if (data_size > 0) {
              cpu_messages[instance_idx].data.data = (uint8_t *) malloc (data_size);
              memcpy(cpu_messages[instance_idx].data.data, data_content, data_size);
            } else {
              cpu_messages[instance_idx].data.data = NULL;
            }

            from_mpz(cpu_messages[instance_idx].caller._limbs, params::BITS/32, caller);
            from_mpz(cpu_messages[instance_idx].value._limbs, params::BITS/32, value);
            from_mpz(cpu_messages[instance_idx].to._limbs, params::BITS/32, to);
            from_mpz(cpu_messages[instance_idx].nonce._limbs, params::BITS/32, nonce);
            from_mpz(cpu_messages[instance_idx].tx.origin._limbs, params::BITS/32, tx_origin);
            from_mpz(cpu_messages[instance_idx].tx.gasprice._limbs, params::BITS/32, tx_gasprice);
            from_mpz(cpu_messages[instance_idx].gas._limbs, params::BITS/32, gas);
            cpu_messages[instance_idx].depth=0;
            cpu_messages[instance_idx].call_type=call_type;
            instance_idx++;
          }
        }
        free(data_content);
      }
      mpz_clear(caller);
      mpz_clear(value);
      mpz_clear(to);
      mpz_clear(nonce);
      mpz_clear(tx_origin);
      mpz_clear(tx_gasprice);
      mpz_clear(gas);
      return cpu_messages;
    }

    
    __host__ static void free_messages(message_content_t *cpu_messages, size_t count) {
      for(size_t idx=0; idx<count; idx++) {
        // data
        free(cpu_messages[idx].data.data);
      }
      free(cpu_messages);
    }

    __host__ static message_content_t *get_gpu_messages(message_content_t *cpu_messages, size_t count) {
      message_content_t *gpu_messages, *tmp_cpu_messages;
      tmp_cpu_messages = (message_content_t *)malloc(count*sizeof(message_content_t));
      memcpy(tmp_cpu_messages, cpu_messages, count*sizeof(message_content_t));
      for(size_t idx=0; idx<count; idx++) {
        // data
        if (tmp_cpu_messages[idx].data.size > 0) {
          cudaMalloc((void **)&(tmp_cpu_messages[idx].data.data), sizeof(uint8_t)*tmp_cpu_messages[idx].data.size);
          cudaMemcpy(tmp_cpu_messages[idx].data.data, cpu_messages[idx].data.data, sizeof(uint8_t)*tmp_cpu_messages[idx].data.size, cudaMemcpyHostToDevice);
        } else {
          tmp_cpu_messages[idx].data.data = NULL;
        }
      }
      //write_messages<params>(stdout, tmp_cpu_instaces, count);
      cudaMalloc((void **)&gpu_messages, sizeof(message_content_t)*count);
      cudaMemcpy(gpu_messages, tmp_cpu_messages, sizeof(message_content_t)*count, cudaMemcpyHostToDevice);
      free(tmp_cpu_messages);
      return gpu_messages;
    }
  
    __host__ static void free_gpu_messages(message_content_t *gpu_messages, size_t count) {
      message_content_t *tmp_cpu_messages;
      tmp_cpu_messages = (message_content_t *)malloc(count*sizeof(message_content_t));
      cudaMemcpy(tmp_cpu_messages, gpu_messages, count*sizeof(message_content_t), cudaMemcpyDeviceToHost);

      for(size_t idx=0; idx<count; idx++) {
        if ( (tmp_cpu_messages[idx].data.size > 0) && (tmp_cpu_messages[idx].data.data != NULL) ) {
          cudaFree(tmp_cpu_messages[idx].data.data);
        }
      }
      free(tmp_cpu_messages);
      cudaFree(gpu_messages);
    }
};


#endif