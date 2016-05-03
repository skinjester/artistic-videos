# artistic-videos

This is the torch implementation for the paper "[Artistic style transfer for videos](http://arxiv.org/abs/1604.08610)", based on neural-style code by Justin Johnson https://github.com/jcjohnson/neural-style .

Our algorithm allows to transfer the style from one image (for example, a painting) to a whole video sequence and generates consistent and stable stylized video sequences.

**Example video:**

[![Artistic style transfer for videos](http://img.youtube.com/vi/Khuj4ASldmU/0.jpg)](https://www.youtube.com/watch?v=Khuj4ASldmU "Artistic style transfer for videos")

## Setup

Tested with Ubuntu 14.04.

* Install torch7 and loadcaffe as described by jcjohnson: [neural-style#setup](https://github.com/jcjohnson/neural-style#setup).
* The frames of the video must be saved as individual image files, one file per frame. This can be easily done using [ffmpeg](https://ffmpeg.org/). For example: `ffmpeg -i video.mp4 frame_%04d.ppm`.
* To use the temporal consistency constraints, you need to set up an utility which estimates the optical flow between two images and creates a flow file in the [middlebury file format](http://vision.middlebury.edu/flow/code/flow-code/README.txt). For example, you can use [DeepFlow](http://lear.inrialpes.fr/src/deepflow/) which we also used in our paper. Then you can make use of the script `makeOptFlow.sh` to generate the optical flow for all frames as well as the certainty of the flow field. Specify the path to the optical flow utility in the first line of this script file.

## Usage

There are two versions of this algorithm, a single-pass and a multi-pass version. The multi-pass version yields better results in case of strong camera motion, but needs more iternations per frame.

Basic usage:

```
th artistic_video.lua <arguments> [-args <fileName>]
```

```
th artistic_video_multiPass.lua <arguments> [-args <fileName>]
```

Arguments can be given by command line and/or written in a file with one argument per line. Specify the path to this file through the option `-args`. Arguments given by command line will override arguments written in this file.

**Basic arguments**:
* `-style_image`: The style image.
* `-content_pattern`: A file path pattern for the individual frames of the videos, for example `frame_%04d.png`.
* `-num_images`: The number of frames.
* `-start_number`: The index of the first frame. Default: 1
* `-gpu`: Zero-indexed ID of the GPU to use; for CPU mode set `-gpu` to -1.

**Arguments for the single-pass algorithm** (only present in `artistic_video.lua`)
* `-flow_pattern`: A file path pattern for files that store the backward flow between the frames. The placeholder in square brackets refers to the frame position where the optical flow starts and the placeholder in braces refers to the frame index where the optical flow points to. For example `flow_[%02d]_{%02d}.flo` means the flow files are named *flow_02_01.flo*, *flow_03_02.flo*, etc. If you use the script included in this repository (makeOptFlow.sh), the filename pattern will be `backward_[%d]_{%d}.flo`.
* `-flowWeight_pattern`: A file path pattern for the weights / certainty of the flow field. These files should be a grey scale image where a white pixel indicates a high flow weight and a black pixel a low weight, respective. Same format as above. If you use the script, the filename pattern will be `reliable_[%d]_{%d}.pgm`.
* `-flow_relative_indices`: The indices for the long-term consistency constraint as comma-separated list. Indices should be relative to the current frame. For example `1,2,4` means it uses frames *i-1*,*i-2* and *i-4* warped for current frame at position *i* as consistency constraint. Default value is 1 which means it uses short-term consistency only. If you use non-default values you have to compute the corresponding long-term flow as well.

**Arguments for the multi-pass algorithm** (only present in `artistic_video_multiPass.lua`)
* `-forwardFlow_pattern`: A file path pattern for the forward flow. Same format as in `-flow_pattern`.
* `-backwardFlow_pattern`: A file path pattern for the backward flow. Same format as above.
* `-forwardFlow_weights_pattern`: A file path pattern for the forward-flow. Same format as above.
* `-backwardFlow_weights_pattern`: A file path pattern for the backward flow. Same format as above.
* `-num_passes`: Number of passes. Default: 15.
* `-use_temporalLoss_after`: Uses temporal consistency loss in given pass and afterwards. Default: `8`.
* `-blendWeight`: The blending factor of the previous stylized frame. The higher this value, the stronger the temporal consistency. Default value is `1` which means that the previous stylized frame is blended equally with the current frame.

**Optimization options**:
* `-content_weight`: How much to weight the content reconstruction term. Default is 5e0.
* `-style_weight`: How much to weight the style reconstruction term. Default is 1e2.
* `-temporal_weight`: How much to weight the temporal consistency loss. Default is 1e3. Set to 0 to disable the temporal consistency loss.
* `-temporal_loss_criterion`: Which error function is used for the temporal consistency loss. Can be either `mse` for the mead squared error or `smoothl1` for the [smooth L1 criterion](https://github.com/torch/nn/blob/master/doc/criterion.md#nn.SmoothL1Criterion).
* `-tv_weight`: Weight of total-variation (TV) regularization; this helps to smooth the image.
  Default is 1e-3. Set to 0 to disable TV regularization.
* `-num_iterations`:
  * Single-pass: Two comma-separated values for the maximum number of iterations for the first frame and for subsequent frames. Default is 2000,1000.
  * Multi-pass: A single value for the number of iterations *per pass*.
* `-tol_loss_relative`: Stop if the relative change of the loss function in an interval of `tol_loss_relative_interval` iterations falls below this threshold. Default is `0.0001` which means that the optimizer stops if the loss function changes less than 0.01% in the given interval. Meaningful values are between `0.001` and `0.0001` in the default interval.
* `-tol_loss_relative_interval`: Se above. Default value: `50`.
* `-init`:
  * Single-pass: Two comma-separated values for the initialization method for the first frame and for subsequent frames; one of `random`, `image`, `prev` or `prevWarped`.
  Default is `random,prevWarped` which uses a noise initialization for the first frame and the previous stylized frame warped for subsequent frames. `image` initializes with the content frames. `prev` initializes with the previous stylized frames without warping.
  * Multi-pass: One value for the initialization method. Either `random` or `image`.
* `-optimizer`: The optimization algorithm to use; either `lbfgs` or `adam`; default is `lbfgs`.
  L-BFGS tends to give better results, but uses more memory. Switching to ADAM will reduce memory usage;
  when using ADAM you will probably need to play with other parameters to get good results, especially
  the style weight, content weight, and learning rate; you may also want to normalize gradients when
  using ADAM.
* `-learning_rate`: Learning rate to use with the ADAM optimizer. Default is 1e1.
* `-normalize_gradients`: If this flag is present, style and content gradients from each layer will be
  L1 normalized. Idea from [andersbll/neural_artistic_style](https://github.com/andersbll/neural_artistic_style).

**Output options**:
* `-output_image`: Name of the output image. Default is `out.png` which will produce output images of the form *out-\<frameIdx\>.png* for the single-pass and *out-\<frameIdx\>_\<passIdx\>.png* for the multi-pass algorithm.
* `-output_folder`: Directory where the output images should be saved.
* `-print_iter`: Print progress every `print_iter` iterations. Set to 0 to disable printing.
* `-save_iter`: Save the image every `save_iter` iterations. Set to 0 to disable saving intermediate results.
* `-save_init`: Set to 1 to save the initialization image; 0 otherwise.

**Other arguments**:
* `-content_layers`: Comma-separated list of layer names to use for content reconstruction.
  Default is `relu4_2`.
* `-style_layers`: Comman-separated list of layer names to use for style reconstruction.
  Default is `relu1_1,relu2_1,relu3_1,relu4_1,relu5_1`.
* `-style_blend_weights`: The weight for blending the style of multiple style images, as a
  comma-separated list, such as `-style_blend_weights 3,7`. By default all style images
  are equally weighted.
* `-style_scale`: Scale at which to extract features from the style image, relative to the size of the content video. Default is `1.0`.
* `-proto_file`: Path to the `deploy.txt` file for the VGG Caffe model.
* `-model_file`: Path to the `.caffemodel` file for the VGG Caffe model.
  Default is the original VGG-19 model; you can also try the normalized VGG-19 model used in the paper.
* `-pooling`: The type of pooling layers to use; one of `max` or `avg`. Default is `max`.
  The VGG-19 models uses max pooling layers, but the paper mentions that replacing these layers with average
  pooling layers can improve the results. I haven't been able to get good results using average pooling, but
  the option is here.
* `-backend`: `nn` or `cudnn`. Default is `nn`. `cudnn` requires
  [cudnn.torch](https://github.com/soumith/cudnn.torch) and may reduce memory usage.
* `-cudnn_autotune`: When using the cuDNN backend, pass this flag to use the built-in cuDNN autotuner to select
  the best convolution algorithms for your architecture. This will make the first iteration a bit slower and can
  take a bit more memory, but may significantly speed up the cuDNN backend.

## Acknowledgement
* This work was inspired by the paper [A Neural Algorithm of Artistic Style](http://arxiv.org/abs/1508.06576) by Leon A. Gatys, Alexander S. Ecker, and Matthias Bethge, which introduced an approach for style transfer in still images.
* Our implementation is based on Justin Johnson's implementation [neural-style](https://github.com/jcjohnson/neural-style).

## Citation

If you use this code or its parts in your research, please cite the following paper:

```
@TechReport{RuderDB2016,
  author = {Manuel Ruder and Alexey Dosovitskiy and Thomas Brox},
  title = {Artistic style transfer for videos},
  institution  = "arXiv:1604.08610",
  year         = "2016",
}
```
