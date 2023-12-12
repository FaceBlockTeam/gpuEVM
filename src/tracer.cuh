// cuEVM: CUDA Ethereum Virtual Machine implementation
// Copyright 2023 Stefan-Dan Ciocirlan (SBIP - Singapore Blockchain Innovation Programme)
// Author: Stefan-Dan Ciocirlan
// Data: 2023-11-30
// SPDX-License-Identifier: MIT

#ifndef _TRACER_H_
#define _TRACER_H_

#include "utils.h"
#include "stack.cuh"
#include "memory.cuh"
#include "state.cuh"

/**
 * The tracer class is used to store the execution trace of the
 * EVM. It is used to generate the execution trace JSON file.
 * It contains the following information:
 * - the address of the contract
 * - the program counter
 * - the opcode
 * - the stack
 * - the memory
 * - the touched accounts
 * - the gas used
 * - the gas limit
 * - the gas refund
 * - the error code
*/
template <class params>
class tracer_t
{
public:
    /**
     * The arithmetical environment used by the arbitrary length
     * integer library.
     */
    typedef arith_env_t<params> arith_t;
    /**
     * The arbitrary length integer type.
     */
    typedef typename arith_t::bn_t bn_t;
    /**
     * The arbitrary length integer type used for the storage.
     * It is defined as the EVM word type.
     */
    typedef cgbn_mem_t<params::BITS> evm_word_t;
    /**
     * The stack type.
    */
    typedef stack_t<params> stack_t;
    /**
     * The stack data type
    */
    typedef typename stack_t::stack_data_t stack_data_t;
    /**
     * The memory type.
    */
    typedef memory_t<params> memory_t;
    /**
     * The memory data type.
    */
    typedef typename memory_t::memory_data_t memory_data_t;
    /**
     * The touch state type.
    */
    typedef touch_state_t<params> touch_state_t;
    /**
     * The touch state data type.
    */
    typedef typename touch_state_t::touch_state_data_t touch_state_data_t;
    static const size_t PAGE_SIZE = 128; /**< The stept of page allocation for the trace*/

    /**
     * The tracer data type.
    */
    typedef struct alignas(32)
    {
        size_t size; /**< The number of elements in the trace*/
        size_t capacity; /**< The capacity allocated of the trace*/
        evm_word_t *addresses; /**< The addresses of the contracts*/
        uint32_t *pcs; /**< The program counters*/
        uint8_t *opcodes; /**< The opcodes*/
        stack_data_t *stacks; /**< The stacks*/
        memory_data_t *memories; /**< The memories*/
        touch_state_data_t *touch_states; /**< The touch states*/
        evm_word_t *gas_useds; /**< The gas used*/
        evm_word_t *gas_limits; /**< The gas limits*/
        evm_word_t *gas_refunds; /**< The gas refunds*/
        uint32_t *error_codes; /**< The error codes*/
    } tracer_data_t;

    tracer_data_t *_content; /**< The content of the tracer*/
    arith_t _arith; /**< The arithmetical environment*/

    /**
     * The constructor of the tracer.
    */
    __host__ __device__ __forceinline__ tracer_t(
        arith_t arith,
        tracer_data_t *content) : _arith(arith),
                                  _content(content)
    {
    }

    /**
     * The destructor of the tracer.
    */
    __host__ __device__ __forceinline__ ~tracer_t()
    {
        _content = NULL;
    }

    /**
     * The grow function when the capacity is full.
    */
    __host__ __device__ __forceinline__ void grow()
    {
        ONE_THREAD_PER_INSTANCE(
            evm_word_t *new_addresses = new evm_word_t[_content->capacity + PAGE_SIZE];
            uint32_t *new_pcs = new uint32_t[_content->capacity + PAGE_SIZE];
            uint8_t *new_opcodes = new uint8_t[_content->capacity + PAGE_SIZE];
            stack_data_t *new_stacks = new stack_data_t[_content->capacity + PAGE_SIZE];
            memory_data_t *new_memories = new memory_data_t[_content->capacity + PAGE_SIZE];
            touch_state_data_t *new_touch_states = new touch_state_data_t[_content->capacity + PAGE_SIZE];
            evm_word_t *new_gas_useds = new evm_word_t[_content->capacity + PAGE_SIZE];
            evm_word_t *new_gas_limits = new evm_word_t[_content->capacity + PAGE_SIZE];
            evm_word_t *new_gas_refunds = new evm_word_t[_content->capacity + PAGE_SIZE];
            uint32_t *new_error_codes = new uint32_t[_content->capacity + PAGE_SIZE];
            if (_content->capacity > 0) {
                memcpy(
                    new_addresses,
                    _content->addresses,
                    sizeof(evm_word_t) * _content->capacity);
                memcpy(
                    new_pcs,
                    _content->pcs,
                    sizeof(uint32_t) * _content->capacity);
                memcpy(
                    new_opcodes,
                    _content->opcodes,
                    sizeof(uint8_t) * _content->capacity);
                
                memcpy(
                    new_stacks,
                    _content->stacks,
                    sizeof(stack_data_t) * _content->capacity);
                memcpy(
                    new_memories,
                    _content->memories,
                    sizeof(memory_data_t) * _content->capacity);
                memcpy(
                    new_touch_states,
                    _content->touch_states,
                    sizeof(touch_state_data_t) * _content->capacity);
                memcpy(
                    new_gas_useds,
                    _content->gas_useds,
                    sizeof(evm_word_t) * _content->capacity);
                memcpy(
                    new_gas_limits,
                    _content->gas_limits,
                    sizeof(evm_word_t) * _content->capacity);
                memcpy(
                    new_gas_refunds,
                    _content->gas_refunds,
                    sizeof(evm_word_t) * _content->capacity);
                memcpy(
                    new_error_codes,
                    _content->error_codes,
                    sizeof(uint32_t) * _content->capacity);
                delete[] _content->addresses;
                delete[] _content->pcs;
                delete[] _content->opcodes;
                delete[] _content->stacks;
                delete[] _content->memories;
                delete[] _content->touch_states;
                delete[] _content->gas_useds;
                delete[] _content->gas_limits;
                delete[] _content->gas_refunds;
                delete[] _content->error_codes;
            }
            _content->capacity = _content->capacity + PAGE_SIZE;
            _content->addresses = new_addresses;
            _content->pcs = new_pcs;
            _content->opcodes = new_opcodes;
            _content->stacks = new_stacks;
            _content->memories = new_memories;
            _content->touch_states = new_touch_states;
            _content->gas_useds = new_gas_useds;
            _content->gas_limits = new_gas_limits;
            _content->gas_refunds = new_gas_refunds;
            _content->error_codes = new_error_codes;
            for (size_t idx = _content->size; idx < _content->capacity; idx++) {
                _content->stacks[idx].stack_base = NULL;
                _content->stacks[idx].stack_offset = 0;
                _content->memories[idx].size = 0;
                _content->memories[idx].allocated_size = 0;
                _content->memories[idx].data = NULL;
                _content->touch_states[idx].touch_accounts.no_accounts = 0;
                _content->touch_states[idx].touch_accounts.accounts = NULL;
                _content->touch_states[idx].touch = NULL;
            }
        )
    }

    /**
     * The push function to add a new element to the trace.
     * @param[in] address The address of the contract.
     * @param[in] pc The program counter.
     * @param[in] opcode The opcode.
     * @param[in] stack The stack.
     * @param[in] memory The memory.
     * @param[in] touch_state The touched accounts.
     * @param[in] gas_used The gas used.
     * @param[in] gas_limit The gas limit.
     * @param[in] gas_refund The gas refund.
     * @param[in] error_code The error code.
    */
    __host__ __device__ __forceinline__ void push(
        bn_t &address,
        uint32_t pc,
        uint8_t opcode,
        stack_t &stack,
        memory_t &memory,
        touch_state_t &touch_state,
        bn_t &gas_used,
        bn_t &gas_limit,
        bn_t &gas_refund,
        uint32_t error_code)
    {
        if (_content->size == _content->capacity)
        {
            grow();
        }
        cgbn_store(
            _arith._env,
            &(_content->addresses[_content->size]),
            address);
        _content->pcs[_content->size] = pc;
        _content->opcodes[_content->size] = opcode;
        cgbn_store(
            _arith._env,
            &(_content->gas_useds[_content->size]),
            gas_used);
        cgbn_store(
            _arith._env,
            &(_content->gas_limits[_content->size]),
            gas_limit);
        cgbn_store(
            _arith._env,
            &(_content->gas_refunds[_content->size]),
            gas_refund);
        _content->error_codes[_content->size] = error_code;
        stack.to_stack_data_t(
            _content->stacks[_content->size]);
        memory.to_memory_data_t(
            _content->memories[_content->size]);
        touch_state.to_touch_state_data_t(
            _content->touch_states[_content->size]);
        ONE_THREAD_PER_INSTANCE(
            _content->size = _content->size + 1;)
    }

    /**
     * Modify the last stack of the trace.
     * @param[in] stack The stack.
    */
    __host__ __device__ __forceinline__ void modify_last_stack(
        stack_t &stack)
    {
        stack.to_stack_data_t(_content->stacks[_content->size - 1]);
    }
    /**
     * Print the trace data structure.
     * @param[in] arith The arithmetical environment.
     * @param[in] tracer_data The trace data structure.
    */
    __host__ __device__ __forceinline__ static void print_tracer_data_t(
        arith_t &arith,
        tracer_data_t &tracer_data)
    {
        printf("Tracer data:\n");
        printf("Size: %lu\n", tracer_data.size);
        for (size_t idx = 0; idx < tracer_data.size; idx++)
        {
            printf("Address: ");
            arith.print_cgbn_memory(tracer_data.addresses[idx]);
            printf("PC: %d\n", tracer_data.pcs[idx]);
            printf("Opcode: %d\n", tracer_data.opcodes[idx]);
            printf("Stack:\n");
            stack_t::print_stack_data_t(arith, tracer_data.stacks[idx]);
            printf("Memory:\n");
            memory_t::print_memory_data_t(arith, tracer_data.memories[idx]);
            printf("Touch state:\n");
            touch_state_t::print_touch_state_data_t(arith, tracer_data.touch_states[idx]);
            printf("Gas used: ");
            arith.print_cgbn_memory(tracer_data.gas_useds[idx]);
            printf("Gas limit: ");
            arith.print_cgbn_memory(tracer_data.gas_limits[idx]);
            printf("Gas refund: ");
            arith.print_cgbn_memory(tracer_data.gas_refunds[idx]);
            printf("Error code: %d\n", tracer_data.error_codes[idx]);
        }
    }

    /**
     * Print the tracer.
    */
    __host__ __device__ void print()
    {
        print_tracer_data_t(_arith, *_content);
    }

    /**
     * Get the json object from the tracer data structure.
     * @param[in] arith The arithmetical environment.
     * @param[in] tracer_data The trace data structure.
     * @return The json object.
    */
    __host__ static cJSON *json_from_tracer_data_t(
        arith_t &arith,
        tracer_data_t &tracer_data)
    {
        char *hex_string_ptr = new char[arith_t::BYTES * 2 + 3];
        cJSON *tracer_json = cJSON_CreateArray();
        cJSON *item = NULL;
        cJSON *stack_json = NULL;
        cJSON *memory_json = NULL;
        cJSON *touch_state_json = NULL;
        for (size_t idx = 0; idx < tracer_data.size; idx++)
        {
            item = cJSON_CreateObject();
            arith.hex_string_from_cgbn_memory(
                hex_string_ptr,
                tracer_data.addresses[idx],
                5);
            cJSON_AddStringToObject(item, "address", hex_string_ptr);
            cJSON_AddNumberToObject(item, "pc", tracer_data.pcs[idx]);
            cJSON_AddNumberToObject(item, "opcode", tracer_data.opcodes[idx]);
            stack_json = stack_t::json_from_stack_data_t(
                arith,
                tracer_data.stacks[idx]);
            cJSON_AddItemToObject(item, "stack", stack_json);
            memory_json = memory_t::json_from_memory_data_t(
                arith,
                tracer_data.memories[idx]);
            cJSON_AddItemToObject(item, "memory", memory_json);
            touch_state_json = touch_state_t::json_from_touch_state_data_t(
                arith,
                tracer_data.touch_states[idx]);
            cJSON_AddItemToObject(item, "touch_state", touch_state_json);
            arith.hex_string_from_cgbn_memory(
                hex_string_ptr,
                tracer_data.gas_useds[idx]);
            cJSON_AddStringToObject(item, "gas_used", hex_string_ptr);
            arith.hex_string_from_cgbn_memory(
                hex_string_ptr,
                tracer_data.gas_limits[idx]);
            cJSON_AddStringToObject(item, "gas_limit", hex_string_ptr);
            arith.hex_string_from_cgbn_memory(
                hex_string_ptr,
                tracer_data.gas_refunds[idx]);
            cJSON_AddStringToObject(item, "gas_refund", hex_string_ptr);
            cJSON_AddNumberToObject(item, "error_code", tracer_data.error_codes[idx]);
            cJSON_AddItemToArray(tracer_json, item);
        }
        delete[] hex_string_ptr;
        hex_string_ptr = NULL;
        return tracer_json;
    }

    /**
     * Get the json object from the tracer.
     * @return The json object.
    */
    __host__ cJSON *json()
    {
        return json_from_tracer_data_t(_arith, *_content);
    }

    /**
     * Get the cpu tracer data structures.
     * @param[in] count The number of tracer data structures.
     * @return The cpu tracer data structures.
    */
    __host__ static tracer_data_t *get_cpu_instances(
        uint32_t count)
    {
        tracer_data_t *cpu_instances = new tracer_data_t[count];
        memset(cpu_instances, 0, sizeof(tracer_data_t) * count);
        return cpu_instances;
    }

    /**
     * Free the cpu tracer data structures.
     * @param[in] cpu_instances The cpu tracer data structures.
     * @param[in] count The number of tracer data structures.
    */
    __host__ static void free_cpu_instances(
        tracer_data_t *cpu_instances,
        uint32_t count)
    {
        for (uint32_t idx = 0; idx < count; idx++)
        {
            if (cpu_instances[idx].capacity > 0)
            {
                delete[] cpu_instances[idx].addresses;
                delete[] cpu_instances[idx].pcs;
                delete[] cpu_instances[idx].opcodes;
                stack_t::free_cpu_instances(cpu_instances[idx].stacks, cpu_instances[idx].capacity);
                //delete[] cpu_instances[idx].stacks;
                memory_t::free_cpu_instances(cpu_instances[idx].memories, cpu_instances[idx].capacity);
                //delete[] cpu_instances[idx].memories;
                touch_state_t::free_cpu_instances(cpu_instances[idx].touch_states, cpu_instances[idx].capacity);
                //delete[] cpu_instances[idx].touch_states;
                delete[] cpu_instances[idx].gas_useds;
                delete[] cpu_instances[idx].gas_limits;
                delete[] cpu_instances[idx].gas_refunds;
                delete[] cpu_instances[idx].error_codes;
                cpu_instances[idx].capacity = 0;
                cpu_instances[idx].size = 0;
                cpu_instances[idx].addresses = NULL;
                cpu_instances[idx].pcs = NULL;
                cpu_instances[idx].opcodes = NULL;
                cpu_instances[idx].stacks = NULL;
                cpu_instances[idx].memories = NULL;
                cpu_instances[idx].touch_states = NULL;
                cpu_instances[idx].gas_useds = NULL;
                cpu_instances[idx].gas_limits = NULL;
                cpu_instances[idx].gas_refunds = NULL;
                cpu_instances[idx].error_codes = NULL;
            }
        }
        delete[] cpu_instances;
    }

    /**
     * Get the gpu tracer data structures from the cpu tracer data structures.
     * @param[in] cpu_instances The cpu tracer data structures.
     * @param[in] count The number of tracer data structures.
     * @return The gpu tracer data structures.
    */
    __host__ static tracer_data_t *get_gpu_instances_from_cpu_instances(
        tracer_data_t *cpu_instances,
        uint32_t count)
    {
        tracer_data_t *gpu_instances, *tmp_cpu_instances;
        CUDA_CHECK(cudaMalloc(
            (void **)&gpu_instances,
            sizeof(tracer_data_t) * count));
        tmp_cpu_instances = new tracer_data_t[count];
        memcpy(
            tmp_cpu_instances,
            cpu_instances,
            sizeof(tracer_data_t) * count);
        for (size_t idx = 0; idx < count; idx++)
        {
            if (tmp_cpu_instances[idx].size > 0)
            {
                tmp_cpu_instances[idx].capacity = tmp_cpu_instances[idx].size;
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].addresses),
                    sizeof(evm_word_t) * tmp_cpu_instances[idx].size));
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].addresses,
                    cpu_instances[idx].addresses,
                    sizeof(evm_word_t) * tmp_cpu_instances[idx].size,
                    cudaMemcpyHostToDevice));
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].pcs),
                    sizeof(uint32_t) * tmp_cpu_instances[idx].size));
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].pcs,
                    cpu_instances[idx].pcs,
                    sizeof(uint32_t) * tmp_cpu_instances[idx].size,
                    cudaMemcpyHostToDevice));
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].opcodes),
                    sizeof(uint8_t) * tmp_cpu_instances[idx].size));
                tmp_cpu_instances[idx].stacks = stack_t::get_gpu_instances_from_cpu_instances(
                    cpu_instances[idx].stacks,
                    cpu_instances[idx].size);
                tmp_cpu_instances[idx].memories = memory_t::get_gpu_instances_from_cpu_instances(
                    cpu_instances[idx].memories,
                    cpu_instances[idx].size);
                tmp_cpu_instances[idx].touch_states = touch_state_t::get_gpu_instances_from_cpu_instances(
                    cpu_instances[idx].touch_states,
                    cpu_instances[idx].size);
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].gas_useds),
                    sizeof(evm_word_t) * tmp_cpu_instances[idx].size));
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].gas_useds,
                    cpu_instances[idx].gas_useds,
                    sizeof(evm_word_t) * tmp_cpu_instances[idx].size,
                    cudaMemcpyHostToDevice));
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].gas_limits),
                    sizeof(evm_word_t) * tmp_cpu_instances[idx].size));
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].gas_limits,
                    cpu_instances[idx].gas_limits,
                    sizeof(evm_word_t) * tmp_cpu_instances[idx].size,
                    cudaMemcpyHostToDevice));
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].gas_refunds),
                    sizeof(evm_word_t) * tmp_cpu_instances[idx].size));
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].gas_refunds,
                    cpu_instances[idx].gas_refunds,
                    sizeof(evm_word_t) * tmp_cpu_instances[idx].size,
                    cudaMemcpyHostToDevice));
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].error_codes),
                    sizeof(uint32_t) * tmp_cpu_instances[idx].size));
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].error_codes,
                    cpu_instances[idx].error_codes,
                    sizeof(uint32_t) * tmp_cpu_instances[idx].size,
                    cudaMemcpyHostToDevice));
            }
            else
            {
                tmp_cpu_instances[idx].capacity = 0;
                tmp_cpu_instances[idx].size = 0;
                tmp_cpu_instances[idx].addresses = NULL;
                tmp_cpu_instances[idx].pcs = NULL;
                tmp_cpu_instances[idx].opcodes = NULL;
                tmp_cpu_instances[idx].stacks = NULL;
                tmp_cpu_instances[idx].memories = NULL;
                tmp_cpu_instances[idx].touch_states = NULL;
                tmp_cpu_instances[idx].gas_useds = NULL;
                tmp_cpu_instances[idx].gas_limits = NULL;
                tmp_cpu_instances[idx].gas_refunds = NULL;
                tmp_cpu_instances[idx].error_codes = NULL;
            }
        }
        CUDA_CHECK(cudaMemcpy(
            gpu_instances,
            tmp_cpu_instances,
            sizeof(tracer_data_t) * count,
            cudaMemcpyHostToDevice));
        return gpu_instances;
    }

    /**
     * Free the gpu tracer data structures.
     * @param[in] gpu_instances The gpu tracer data structures.
     * @param[in] count The number of tracer data structures.
    */
    __host__ static void free_gpu_instances(
        tracer_data_t *gpu_instances,
        uint32_t count)
    {
        tracer_data_t *tmp_cpu_instances;
        tmp_cpu_instances = new tracer_data_t[count];
        CUDA_CHECK(cudaMemcpy(
            tmp_cpu_instances,
            gpu_instances,
            sizeof(tracer_data_t) * count,
            cudaMemcpyDeviceToHost));
        for (size_t idx = 0; idx < count; idx++)
        {
            if (tmp_cpu_instances[idx].size > 0)
            {
                CUDA_CHECK(cudaFree(tmp_cpu_instances[idx].addresses));
                CUDA_CHECK(cudaFree(tmp_cpu_instances[idx].pcs));
                CUDA_CHECK(cudaFree(tmp_cpu_instances[idx].opcodes));
                stack_data_t::free_gpu_instances(tmp_cpu_instances[idx].stacks, tmp_cpu_instances[idx].size);
                memory_data_t::free_gpu_instances(tmp_cpu_instances[idx].memories, tmp_cpu_instances[idx].size);
                touch_state_data_t::free_gpu_instances(tmp_cpu_instances[idx].touch_states, tmp_cpu_instances[idx].size);
                CUDA_CHECK(cudaFree(tmp_cpu_instances[idx].gas_useds));
                CUDA_CHECK(cudaFree(tmp_cpu_instances[idx].gas_limits));
                CUDA_CHECK(cudaFree(tmp_cpu_instances[idx].gas_refunds));
                CUDA_CHECK(cudaFree(tmp_cpu_instances[idx].error_codes));
            }
        }
        delete[] tmp_cpu_instances;
        CUDA_CHECK(cudaFree(gpu_instances));
    }

    /**
     * Get the cpu tracer data structures from the gpu tracer data structures.
     * Frees the GPU memory.
     * @param[in] gpu_instances The gpu tracer data structures.
     * @param[in] count The number of tracer data structures.
     * @return The cpu tracer data structures.
    */
    __host__ static tracer_data_t *get_cpu_instances_from_gpu_instances(
        tracer_data_t *gpu_instances,
        uint32_t count)
    {
        printf("Copying the tracer data structures...\n");
        tracer_data_t *cpu_instances, *tmp_gpu_instances, *tmp_cpu_instances;
        cpu_instances = new tracer_data_t[count];
        CUDA_CHECK(cudaMemcpy(
            cpu_instances,
            gpu_instances,
            sizeof(tracer_data_t) * count,
            cudaMemcpyDeviceToHost));
        printf("Copying the tracer data structures...\n");
        tmp_cpu_instances = new tracer_data_t[count];
        memcpy(
            tmp_cpu_instances,
            cpu_instances,
            sizeof(tracer_data_t) * count);
        printf("Copying the tracer data structures...\n");
        // allocate the necessary memory for the transfer
        // of the data arrays
        for (size_t idx = 0; idx < count; idx++)
        {
            if (cpu_instances[idx].size > 0)
            {
                tmp_cpu_instances[idx].capacity = cpu_instances[idx].size;
                tmp_cpu_instances[idx].size = cpu_instances[idx].size;
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].addresses),
                    sizeof(evm_word_t) * cpu_instances[idx].size));
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].pcs),
                    sizeof(uint32_t) * cpu_instances[idx].size));
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].opcodes),
                    sizeof(uint8_t) * cpu_instances[idx].size));
                // reset the stack data structures
                cpu_instances[idx].stacks = stack_t::get_cpu_instances(
                    cpu_instances[idx].size);
                tmp_cpu_instances[idx].stacks = stack_t::get_gpu_instances_from_cpu_instances(
                    cpu_instances[idx].stacks,
                    cpu_instances[idx].size);
                delete[] cpu_instances[idx].stacks;
                cpu_instances[idx].stacks = NULL;

                // reset the memory data structures
                cpu_instances[idx].memories = memory_t::get_cpu_instances(
                    cpu_instances[idx].size);
                tmp_cpu_instances[idx].memories = memory_t::get_gpu_instances_from_cpu_instances(
                    cpu_instances[idx].memories,
                    cpu_instances[idx].size);
                delete[] cpu_instances[idx].memories;
                cpu_instances[idx].memories = NULL;

                // reset the touch state data structures
                cpu_instances[idx].touch_states = touch_state_t::get_cpu_instances(
                    cpu_instances[idx].size);
                tmp_cpu_instances[idx].touch_states = touch_state_t::get_gpu_instances_from_cpu_instances(
                    cpu_instances[idx].touch_states,
                    cpu_instances[idx].size);
                delete[] cpu_instances[idx].touch_states;
                cpu_instances[idx].touch_states = NULL;

                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].gas_useds),
                    sizeof(evm_word_t) * cpu_instances[idx].size));
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].gas_limits),
                    sizeof(evm_word_t) * cpu_instances[idx].size));
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].gas_refunds),
                    sizeof(evm_word_t) * cpu_instances[idx].size));
                CUDA_CHECK(cudaMalloc(
                    (void **)&(tmp_cpu_instances[idx].error_codes),
                    sizeof(uint32_t) * cpu_instances[idx].size));
            }
            else
            {
                tmp_cpu_instances[idx].capacity = 0;
                tmp_cpu_instances[idx].size = 0;
                tmp_cpu_instances[idx].addresses = NULL;
                tmp_cpu_instances[idx].pcs = NULL;
                tmp_cpu_instances[idx].opcodes = NULL;
                tmp_cpu_instances[idx].stacks = NULL;
                tmp_cpu_instances[idx].memories = NULL;
                tmp_cpu_instances[idx].touch_states = NULL;
                tmp_cpu_instances[idx].gas_useds = NULL;
                tmp_cpu_instances[idx].gas_limits = NULL;
                tmp_cpu_instances[idx].gas_refunds = NULL;
                tmp_cpu_instances[idx].error_codes = NULL;
            }
        }
        printf("Copying the tracer data structures...\n");
        CUDA_CHECK(cudaMalloc(
            (void **)&tmp_gpu_instances,
            sizeof(tracer_data_t) * count));
        printf("Copying the tracer data structures...\n");
        CUDA_CHECK(cudaMemcpy(
            tmp_gpu_instances,
            tmp_cpu_instances,
            sizeof(tracer_data_t) * count,
            cudaMemcpyHostToDevice));
        printf("Copying the tracer data structures...\n");
        delete[] tmp_cpu_instances;
        tmp_cpu_instances = NULL;
        printf("Copying the data arrays...\n");
        // copy the data array with the kernel
        kernel_tracers<params><<<1, count>>>(tmp_gpu_instances, gpu_instances, count);
        CUDA_CHECK(cudaDeviceSynchronize());
        CUDA_CHECK(cudaFree(gpu_instances));
        printf("Copying the data arrays done.\n");
        gpu_instances = tmp_gpu_instances;

        // copy the data array to CPUs
        CUDA_CHECK(cudaMemcpy(
            cpu_instances,
            gpu_instances,
            sizeof(tracer_data_t) * count,
            cudaMemcpyDeviceToHost));
        tmp_cpu_instances = new tracer_data_t[count];
        memcpy(
            tmp_cpu_instances,
            cpu_instances,
            sizeof(tracer_data_t) * count);
        for (size_t idx = 0; idx < count; idx++)
        {
            if (cpu_instances[idx].size > 0)
            {
                tmp_cpu_instances[idx].capacity = cpu_instances[idx].size;
                tmp_cpu_instances[idx].size = cpu_instances[idx].size;
                tmp_cpu_instances[idx].addresses = new evm_word_t[cpu_instances[idx].size];
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].addresses,
                    cpu_instances[idx].addresses,
                    sizeof(evm_word_t) * cpu_instances[idx].size,
                    cudaMemcpyDeviceToHost));
                CUDA_CHECK(cudaFree(cpu_instances[idx].addresses));
                tmp_cpu_instances[idx].pcs = new uint32_t[cpu_instances[idx].size];
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].pcs,
                    cpu_instances[idx].pcs,
                    sizeof(uint32_t) * cpu_instances[idx].size,
                    cudaMemcpyDeviceToHost));
                CUDA_CHECK(cudaFree(cpu_instances[idx].pcs));
                tmp_cpu_instances[idx].opcodes = new uint8_t[cpu_instances[idx].size];
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].opcodes,
                    cpu_instances[idx].opcodes,
                    sizeof(uint8_t) * cpu_instances[idx].size,
                    cudaMemcpyDeviceToHost));
                CUDA_CHECK(cudaFree(cpu_instances[idx].opcodes));
                tmp_cpu_instances[idx].stacks = stack_t::get_cpu_instances_from_gpu_instances(
                    cpu_instances[idx].stacks,
                    cpu_instances[idx].size);
                tmp_cpu_instances[idx].memories = memory_t::get_cpu_instances_from_gpu_instances(
                    cpu_instances[idx].memories,
                    cpu_instances[idx].size);
                tmp_cpu_instances[idx].touch_states = touch_state_t::get_cpu_instances_from_gpu_instances(
                    cpu_instances[idx].touch_states,
                    cpu_instances[idx].size);
                tmp_cpu_instances[idx].gas_useds = new evm_word_t[cpu_instances[idx].size];
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].gas_useds,
                    cpu_instances[idx].gas_useds,
                    sizeof(evm_word_t) * cpu_instances[idx].size,
                    cudaMemcpyDeviceToHost));
                CUDA_CHECK(cudaFree(cpu_instances[idx].gas_useds));
                tmp_cpu_instances[idx].gas_limits = new evm_word_t[cpu_instances[idx].size];
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].gas_limits,
                    cpu_instances[idx].gas_limits,
                    sizeof(evm_word_t) * cpu_instances[idx].size,
                    cudaMemcpyDeviceToHost));
                CUDA_CHECK(cudaFree(cpu_instances[idx].gas_limits));
                tmp_cpu_instances[idx].gas_refunds = new evm_word_t[cpu_instances[idx].size];
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].gas_refunds,
                    cpu_instances[idx].gas_refunds,
                    sizeof(evm_word_t) * cpu_instances[idx].size,
                    cudaMemcpyDeviceToHost));
                CUDA_CHECK(cudaFree(cpu_instances[idx].gas_refunds));
                tmp_cpu_instances[idx].error_codes = new uint32_t[cpu_instances[idx].size];
                CUDA_CHECK(cudaMemcpy(
                    tmp_cpu_instances[idx].error_codes,
                    cpu_instances[idx].error_codes,
                    sizeof(uint32_t) * cpu_instances[idx].size,
                    cudaMemcpyDeviceToHost));
                CUDA_CHECK(cudaFree(cpu_instances[idx].error_codes));
            }
            else
            {
                tmp_cpu_instances[idx].capacity = 0;
                tmp_cpu_instances[idx].size = 0;
                tmp_cpu_instances[idx].addresses = NULL;
                tmp_cpu_instances[idx].pcs = NULL;
                tmp_cpu_instances[idx].opcodes = NULL;
                tmp_cpu_instances[idx].stacks = NULL;
                tmp_cpu_instances[idx].memories = NULL;
                tmp_cpu_instances[idx].touch_states = NULL;
                tmp_cpu_instances[idx].gas_useds = NULL;
                tmp_cpu_instances[idx].gas_limits = NULL;
                tmp_cpu_instances[idx].gas_refunds = NULL;
                tmp_cpu_instances[idx].error_codes = NULL;
            }
        }
        memcpy(
            cpu_instances,
            tmp_cpu_instances,
            sizeof(tracer_data_t) * count);
        delete[] tmp_cpu_instances;
        tmp_cpu_instances = NULL;
        CUDA_CHECK(cudaFree(gpu_instances));
        return cpu_instances;
    }
};

/**
 * The kernel to copy the tracer data structures.
 * @param[out] dst_instances The destination tracer data structures.
 * @param[in] src_instances The source tracer data structures.
 * @param[in] count The number of tracer data structures.
*/
template <class params>
__global__ void kernel_tracers(
    typename tracer_t<params>::tracer_data_t *dst_instances,
    typename tracer_t<params>::tracer_data_t *src_instances,
    uint32_t count)
{
    uint32_t instance = blockIdx.x * blockDim.x + threadIdx.x;
    typedef typename tracer_t<params>::tracer_data_t tracer_data_t;
    typedef cgbn_mem_t<params::BITS> evm_word_t;

    if (instance >= count)
        return;

    if (src_instances[instance].size > 0)
    {
        memcpy(
            dst_instances[instance].addresses,
            src_instances[instance].addresses,
            src_instances[instance].size * sizeof(evm_word_t));
        memcpy(
            dst_instances[instance].pcs,
            src_instances[instance].pcs,
            src_instances[instance].size * sizeof(uint32_t));
        memcpy(
            dst_instances[instance].opcodes,
            src_instances[instance].opcodes,
            src_instances[instance].size * sizeof(uint8_t));
        memcpy(
            dst_instances[instance].stacks,
            src_instances[instance].stacks,
            src_instances[instance].size * sizeof(typename tracer_t<params>::stack_data_t));
        memcpy(
            dst_instances[instance].memories,
            src_instances[instance].memories,
            src_instances[instance].size * sizeof(typename tracer_t<params>::memory_data_t));
        memcpy(
            dst_instances[instance].touch_states,
            src_instances[instance].touch_states,
            src_instances[instance].size * sizeof(typename tracer_t<params>::touch_state_data_t));
        memcpy(
            dst_instances[instance].gas_useds,
            src_instances[instance].gas_useds,
            src_instances[instance].size * sizeof(evm_word_t));
        memcpy(
            dst_instances[instance].gas_limits,
            src_instances[instance].gas_limits,
            src_instances[instance].size * sizeof(evm_word_t));
        memcpy(
            dst_instances[instance].gas_refunds,
            src_instances[instance].gas_refunds,
            src_instances[instance].size * sizeof(evm_word_t));
        memcpy(
            dst_instances[instance].error_codes,
            src_instances[instance].error_codes,
            src_instances[instance].size * sizeof(uint32_t));
        delete[] src_instances[instance].addresses;
        delete[] src_instances[instance].pcs;
        delete[] src_instances[instance].opcodes;
        delete[] src_instances[instance].stacks;
        delete[] src_instances[instance].memories;
        delete[] src_instances[instance].touch_states;
        delete[] src_instances[instance].gas_useds;
        delete[] src_instances[instance].gas_limits;
        delete[] src_instances[instance].gas_refunds;
        delete[] src_instances[instance].error_codes;
        src_instances[instance].size = 0;
        src_instances[instance].capacity = 0;
        src_instances[instance].addresses = NULL;
        src_instances[instance].pcs = NULL;
        src_instances[instance].opcodes = NULL;
        src_instances[instance].stacks = NULL;
        src_instances[instance].memories = NULL;
        src_instances[instance].touch_states = NULL;
        src_instances[instance].gas_useds = NULL;
        src_instances[instance].gas_limits = NULL;
        src_instances[instance].gas_refunds = NULL;
        src_instances[instance].error_codes = NULL;
    }
}

#endif